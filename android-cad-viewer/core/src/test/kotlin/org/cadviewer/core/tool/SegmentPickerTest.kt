package org.cadviewer.core.tool

import org.cadviewer.core.dimension.DimensionStyle
import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.measure.MeasurementFormatter
import org.cadviewer.core.model.CadCircle
import org.cadviewer.core.model.CadLine
import org.cadviewer.core.model.CadPolyline
import org.cadviewer.core.model.DrawingUnits
import org.cadviewer.core.model.PolylineVertex
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SegmentPickerTest {

    private val style = DimensionStyle(textHeight = 1.0, arrowSize = 1.0)

    @Test
    fun `tocca la linea piu' vicina fra quelle del disegno`() {
        val entities = listOf(
            CadLine(Vec2(0.0, 0.0), Vec2(4000.0, 0.0)),
            CadLine(Vec2(0.0, 3000.0), Vec2(4000.0, 3000.0)),
        )

        val picked = SegmentPicker.nearest(entities, Vec2(2000.0, 120.0), tolerance = 200.0)

        assertNotNull(picked)
        assertEquals(Vec2(0.0, 0.0), picked.start)
        assertEquals(4000.0, picked.length)
    }

    @Test
    fun `oltre la tolleranza non prende niente`() {
        val entities = listOf(CadLine(Vec2(0.0, 0.0), Vec2(4000.0, 0.0)))

        assertNull(SegmentPicker.nearest(entities, Vec2(2000.0, 900.0), tolerance = 200.0))
    }

    @Test
    fun `prende il singolo lato della polilinea che e' stato toccato`() {
        // Muro perimetrale disegnato come polilinea chiusa: toccando il lato destro si deve
        // ottenere quel lato, non l'intero contorno.
        val room = CadPolyline(
            vertices = listOf(
                PolylineVertex(Vec2(0.0, 0.0)),
                PolylineVertex(Vec2(4200.0, 0.0)),
                PolylineVertex(Vec2(4200.0, 3000.0)),
                PolylineVertex(Vec2(0.0, 3000.0)),
            ),
            closed = true,
        )

        val picked = SegmentPicker.nearest(listOf(room), Vec2(4190.0, 1500.0), tolerance = 100.0)

        assertNotNull(picked)
        assertEquals(3000.0, picked.length)
        assertEquals(4200.0, picked.midpoint.x)
    }

    @Test
    fun `un cerchio non e' una linea e viene ignorato`() {
        val entities = listOf(CadCircle(Vec2(0.0, 0.0), 500.0))

        assertNull(SegmentPicker.nearest(entities, Vec2(500.0, 0.0), tolerance = 100.0))
    }

    @Test
    fun `fra muri paralleli misura la luce in perpendicolare`() {
        val bottom = PickedSegment(Vec2(0.0, 0.0), Vec2(4000.0, 0.0))
        val top = PickedSegment(Vec2(0.0, 3000.0), Vec2(4000.0, 3000.0))

        val (onBottom, onTop) = SegmentPicker.closestPoints(bottom, top)

        assertEquals(3000.0, onBottom.distanceTo(onTop), 1e-9)
        // A meta' della sovrapposizione, cioe' dove la luce si legge davvero.
        assertEquals(2000.0, onBottom.x, 1e-9)
        assertEquals(2000.0, onTop.x, 1e-9)
    }

    @Test
    fun `la luce si misura anche dove i due muri si sovrappongono solo in parte`() {
        val bottom = PickedSegment(Vec2(0.0, 0.0), Vec2(4000.0, 0.0))
        val top = PickedSegment(Vec2(3000.0, 2500.0), Vec2(9000.0, 2500.0))

        val (onBottom, onTop) = SegmentPicker.closestPoints(bottom, top)

        assertEquals(2500.0, onBottom.distanceTo(onTop), 1e-9)
        // Sovrapposizione da 3000 a 4000: la misura cade in mezzo, a 3500.
        assertEquals(3500.0, onBottom.x, 1e-9)
    }

    @Test
    fun `muri sfalsati che non si guardano danno la distanza fra gli spigoli`() {
        val left = PickedSegment(Vec2(0.0, 0.0), Vec2(1000.0, 0.0))
        val right = PickedSegment(Vec2(2000.0, 0.0), Vec2(3000.0, 0.0))

        val (onLeft, onRight) = SegmentPicker.closestPoints(left, right)

        assertEquals(1000.0, onLeft.distanceTo(onRight), 1e-9)
        assertEquals(Vec2(1000.0, 0.0), onLeft)
        assertEquals(Vec2(2000.0, 0.0), onRight)
    }

    @Test
    fun `fra segmenti obliqui misura la distanza minima`() {
        val horizontal = PickedSegment(Vec2(0.0, 0.0), Vec2(1000.0, 0.0))
        val oblique = PickedSegment(Vec2(2000.0, 500.0), Vec2(3000.0, 2000.0))

        val (onHorizontal, onOblique) = SegmentPicker.closestPoints(horizontal, oblique)

        assertEquals(Vec2(1000.0, 0.0), onHorizontal)
        assertEquals(Vec2(2000.0, 500.0), onOblique)
        assertEquals(oblique.start.distanceTo(Vec2(1000.0, 0.0)), onHorizontal.distanceTo(onOblique), 1e-9)
    }

    @Test
    fun `due segmenti che si incrociano hanno distanza nulla`() {
        val horizontal = PickedSegment(Vec2(-100.0, 0.0), Vec2(100.0, 0.0))
        val vertical = PickedSegment(Vec2(0.0, -100.0), Vec2(0.0, 100.0))

        val (a, b) = SegmentPicker.closestPoints(horizontal, vertical)

        assertEquals(a, b)
        assertEquals(Vec2.ZERO, a)
    }

    @Test
    fun `la quota di un segmento ne misura la lunghezza e si stacca di lato`() {
        val wall = PickedSegment(Vec2(0.0, 0.0), Vec2(4200.0, 0.0))

        val dimension = DimensionBuilder.lengthOf(wall, style)

        assertNotNull(dimension)
        assertEquals(4200.0, dimension.measure(), 1e-9)
        // La linea di quota non deve cadere sul muro, altrimenti il numero ci finisce sopra.
        val geometry = dimension.geometry(millimetreFormatter())
        assertTrue(geometry.segments.all { it.start.y != 0.0 || it.end.y != 0.0 })
    }

    @Test
    fun `la quota fra due muri paralleli misura la loro luce`() {
        val bottom = PickedSegment(Vec2(0.0, 0.0), Vec2(4000.0, 0.0))
        val top = PickedSegment(Vec2(0.0, 3000.0), Vec2(4000.0, 3000.0))

        val dimension = DimensionBuilder.distanceBetween(bottom, top, style)

        assertNotNull(dimension)
        assertEquals(3000.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `due muri che si incontrano non producono una quota`() {
        val horizontal = PickedSegment(Vec2(0.0, 0.0), Vec2(1000.0, 0.0))
        val vertical = PickedSegment(Vec2(500.0, -500.0), Vec2(500.0, 500.0))

        assertNull(DimensionBuilder.distanceBetween(horizontal, vertical, style))
    }

    @Test
    fun `un segmento degenere non produce una quota`() {
        val point = PickedSegment(Vec2(10.0, 10.0), Vec2(10.0, 10.0))

        assertNull(DimensionBuilder.lengthOf(point, style))
    }

    private fun millimetreFormatter() = MeasurementFormatter(drawingUnits = DrawingUnits.MILLIMETERS)
}
