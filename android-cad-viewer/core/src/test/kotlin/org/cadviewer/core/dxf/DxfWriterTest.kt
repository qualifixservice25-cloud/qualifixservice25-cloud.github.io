package org.cadviewer.core.dxf

import org.cadviewer.core.dimension.DimensionStyle
import org.cadviewer.core.dimension.LinearDimension
import org.cadviewer.core.dimension.LinearOrientation
import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.measure.MeasurementFormatter
import org.cadviewer.core.model.CadArc
import org.cadviewer.core.model.CadCircle
import org.cadviewer.core.model.CadDocument
import org.cadviewer.core.model.CadLayer
import org.cadviewer.core.model.CadLine
import org.cadviewer.core.model.CadPolyline
import org.cadviewer.core.model.CadSolid
import org.cadviewer.core.model.CadText
import org.cadviewer.core.model.DrawingUnits
import org.cadviewer.core.model.PolylineVertex
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class DxfWriterTest {

    private val document = CadDocument(
        layers = listOf(CadLayer("MURI"), CadLayer("SPENTO", visible = false)),
        blocks = emptyMap(),
        entities = listOf(
            CadLine(Vec2(0.0, 0.0), Vec2(100.0, 0.0), layer = "MURI"),
            CadCircle(Vec2(50.0, 25.0), 5.0, layer = "MURI"),
            CadArc(Vec2(0.0, 0.0), 10.0, 0.0, 90.0, layer = "MURI"),
            CadPolyline(
                vertices = listOf(
                    PolylineVertex(Vec2(0.0, 50.0)),
                    PolylineVertex(Vec2(20.0, 50.0), bulge = 0.5),
                    PolylineVertex(Vec2(40.0, 50.0)),
                ),
                layer = "MURI",
            ),
            CadText(Vec2(5.0, 60.0), "Parete 12,5", height = 2.5, layer = "MURI"),
        ),
        units = DrawingUnits.MILLIMETERS,
    )

    private val formatter = MeasurementFormatter(DrawingUnits.MILLIMETERS, linearPrecision = 0)

    @Test
    fun `il file esportato si rilegge con lo stesso contenuto`() {
        val reparsed = DxfParser.parse(DxfWriter.write(document))

        assertEquals(DrawingUnits.MILLIMETERS, reparsed.units)
        assertEquals(1, reparsed.entities.filterIsInstance<CadLine>().size)
        assertEquals(1, reparsed.entities.filterIsInstance<CadCircle>().size)
        assertEquals(1, reparsed.entities.filterIsInstance<CadText>().size)

        val line = reparsed.entities.filterIsInstance<CadLine>().single()
        assertTrue(line.start.isCloseTo(Vec2(0.0, 0.0), 1e-6))
        assertTrue(line.end.isCloseTo(Vec2(100.0, 0.0), 1e-6))

        val arc = reparsed.entities.filterIsInstance<CadArc>().single()
        assertEquals(10.0, arc.radius, 1e-6)
        assertEquals(90.0, arc.endAngleDeg, 1e-6)
    }

    @Test
    fun `il bulge sopravvive al giro di scrittura e rilettura`() {
        val reparsed = DxfParser.parse(DxfWriter.write(document))
        val polyline = reparsed.entities.filterIsInstance<CadPolyline>().single()
        assertEquals(3, polyline.vertices.size)
        assertEquals(0.5, polyline.vertices[1].bulge, 1e-6)
    }

    @Test
    fun `lo stato spento di un layer viene conservato`() {
        val reparsed = DxfParser.parse(DxfWriter.write(document))
        assertEquals(true, assertNotNull(reparsed.layer("MURI")).visible)
        assertEquals(false, assertNotNull(reparsed.layer("SPENTO")).visible)
    }

    @Test
    fun `le quote vengono esportate su un layer dedicato`() {
        val dimension = LinearDimension(
            first = Vec2(0.0, 0.0),
            second = Vec2(100.0, 0.0),
            dimLinePoint = Vec2(0.0, -20.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = DimensionStyle(precision = 0),
        )
        val text = DxfWriter.write(document, dimensions = listOf(dimension), formatter = formatter)
        val reparsed = DxfParser.parse(text)

        val quoteEntities = reparsed.entities.filter { it.layer == DimensionStyle.QUOTE_LAYER }
        assertTrue(quoteEntities.isNotEmpty(), "le quote devono finire sul layer dedicato")
        assertEquals(2, quoteEntities.filterIsInstance<CadSolid>().size, "due frecce piene")

        val label = quoteEntities.filterIsInstance<CadText>().single()
        assertEquals("100 mm", label.value)
        assertNotNull(reparsed.layer(DimensionStyle.QUOTE_LAYER), "il layer va dichiarato in tabella")
    }

    @Test
    fun `i simboli speciali usano le sequenze compatibili`() {
        val withSymbols = CadDocument(
            layers = listOf(CadLayer("0")),
            blocks = emptyMap(),
            entities = listOf(CadText(Vec2.ZERO, "Ø20 a 45°", height = 2.5)),
        )
        val exported = DxfWriter.write(withSymbols)
        assertContains(exported, "%%c20 a 45%%d")

        val reparsed = DxfParser.parse(exported)
        assertEquals("Ø20 a 45°", reparsed.entities.filterIsInstance<CadText>().single().value)
    }

    @Test
    fun `il file esportato dichiara la versione R12`() {
        val exported = DxfWriter.write(document)
        assertContains(exported, "AC1009")
        assertTrue(exported.trimEnd().endsWith("EOF"))
    }
}
