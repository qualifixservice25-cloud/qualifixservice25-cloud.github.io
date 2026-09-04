package org.qualifix.cad.core

import org.qualifix.cad.core.dimension.DimensionStyle
import org.qualifix.cad.core.dimension.LinearDimension
import org.qualifix.cad.core.dxf.DxfParser
import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.measure.MeasurementFormatter
import org.qualifix.cad.core.model.DrawingUnits
import org.qualifix.cad.core.snap.SnapEngine
import org.qualifix.cad.core.snap.SnapType
import org.qualifix.cad.core.tool.CadTool
import org.qualifix.cad.core.tool.DimensionBuilder
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Prova d'insieme sul disegno di esempio distribuito con il progetto: si apre il file, ci si
 * aggancia a uno spigolo del muro e si quota la stanza.
 *
 * E' il percorso che fa l'utente in cantiere, quindi vale la pena verificarlo tutto insieme e
 * non solo a pezzi: se questo test passa, l'app misura la parete giusta.
 */
class SampleDrawingTest {

    private val sampleFile = File("../samples/locale-esempio.dxf")

    @Test
    fun `il disegno di esempio si apre senza avvisi`() {
        assertTrue(sampleFile.exists(), "manca il file di esempio: ${sampleFile.absolutePath}")
        val document = DxfParser.parse(sampleFile.readText())

        assertEquals(DrawingUnits.MILLIMETERS, document.units)
        assertEquals(emptyList(), document.warnings)
        assertEquals(3, document.layers.size)
        assertTrue(document.entities.size >= 10)
    }

    @Test
    fun `l ingombro corrisponde alla stanza disegnata`() {
        val document = DxfParser.parse(sampleFile.readText())
        val bounds = document.bounds
        assertEquals(0.0, bounds.minX, 1e-6)
        assertEquals(0.0, bounds.minY, 1e-6)
        assertEquals(4200.0, bounds.maxX, 1e-6)
        assertEquals(3000.0, bounds.maxY, 1e-6)
    }

    @Test
    fun `si aggancia allo spigolo interno e si quota la parete`() {
        val document = DxfParser.parse(sampleFile.readText())
        val entities = document.flattenedEntities()
        val engine = SnapEngine(entities)

        // Tocco impreciso vicino allo spigolo interno in basso a sinistra (100, 100).
        val firstSnap = assertNotNull(
            engine.snap(Vec2(118.0, 92.0), radius = 60.0, types = SnapType.ALL),
        )
        assertEquals(SnapType.ENDPOINT, firstSnap.type)
        assertTrue(firstSnap.point.isCloseTo(Vec2(100.0, 100.0), 1e-6))

        // Tocco vicino allo spigolo interno in basso a destra (4100, 100).
        val secondSnap = assertNotNull(
            engine.snap(Vec2(4085.0, 115.0), radius = 60.0, types = SnapType.ALL),
        )
        assertTrue(secondSnap.point.isCloseTo(Vec2(4100.0, 100.0), 1e-6))

        val dimension = assertIs<LinearDimension>(
            DimensionBuilder.build(
                tool = CadTool.LINEAR,
                points = listOf(firstSnap.point, secondSnap.point, Vec2(2100.0, -400.0)),
                // I decimali li decide lo stile di quota, come la variabile DIMDEC del CAD:
                // in millimetri una parete si quota a numero intero.
                style = DimensionStyle.forDrawing(document.bounds).copy(precision = 0),
                entities = entities,
            ),
        )
        assertEquals(4000.0, dimension.measure(), 1e-6, "luce interna della stanza")

        val inMillimeters = MeasurementFormatter(DrawingUnits.MILLIMETERS)
        assertEquals("4000 mm", dimension.text(inMillimeters))

        // La stessa quota letta in metri: cambiano unita' e decimali, non la misura.
        val inMeters = MeasurementFormatter(
            drawingUnits = DrawingUnits.MILLIMETERS,
            displayUnits = DrawingUnits.METERS,
        )
        val withDecimals = dimension.copy(style = dimension.style.copy(precision = 2))
        assertEquals("4.00 m", withDecimals.text(inMeters))
    }

    @Test
    fun `quota il diametro del tavolo tondo`() {
        val document = DxfParser.parse(sampleFile.readText())
        val entities = document.flattenedEntities()

        val dimension = assertNotNull(
            DimensionBuilder.build(
                tool = CadTool.DIAMETER,
                points = listOf(Vec2(3395.0, 810.0), Vec2(4000.0, 800.0)),
                style = DimensionStyle.forDrawing(document.bounds),
                entities = entities,
                circularTolerance = 200.0,
            ),
        )
        assertEquals(900.0, dimension.measure(), 1e-6)
        assertTrue(dimension.text(MeasurementFormatter(DrawingUnits.MILLIMETERS)).startsWith("Ø"))
    }

    @Test
    fun `quota l apertura della porta con una quota angolare`() {
        val document = DxfParser.parse(sampleFile.readText())
        val entities = document.flattenedEntities()

        // L'anta e' un arco di 90 gradi con centro nel cardine a (900, 100).
        val hinge = Vec2(900.0, 100.0)
        val dimension = assertNotNull(
            DimensionBuilder.build(
                tool = CadTool.ANGULAR,
                points = listOf(hinge, Vec2(1700.0, 100.0), Vec2(900.0, 900.0), Vec2(1200.0, 400.0)),
                style = DimensionStyle.forDrawing(document.bounds),
                entities = entities,
            ),
        )
        assertEquals(90.0, dimension.measure(), 1e-6)
    }
}
