package org.qualifix.cad.core.snap

import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.model.CadCircle
import org.qualifix.cad.core.model.CadLine
import org.qualifix.cad.core.model.CadPolyline
import org.qualifix.cad.core.model.PolylineVertex
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SnapEngineTest {

    private val horizontal = CadLine(Vec2(0.0, 0.0), Vec2(100.0, 0.0))
    private val vertical = CadLine(Vec2(50.0, -50.0), Vec2(50.0, 50.0))
    private val circle = CadCircle(Vec2(0.0, 100.0), 10.0)
    private val engine = SnapEngine(listOf(horizontal, vertical, circle))

    @Test
    fun `il punto finale ha la precedenza sul punto vicino`() {
        val result = assertNotNull(engine.snap(Vec2(2.0, 1.0), radius = 5.0, types = SnapType.ALL))
        assertEquals(SnapType.ENDPOINT, result.type)
        assertTrue(result.point.isCloseTo(Vec2(0.0, 0.0), 1e-9))
    }

    @Test
    fun `riconosce l intersezione fra due entita incrociate`() {
        val result = assertNotNull(engine.snap(Vec2(51.0, 1.5), radius = 5.0))
        assertEquals(SnapType.INTERSECTION, result.type)
        assertTrue(result.point.isCloseTo(Vec2(50.0, 0.0), 1e-9))
    }

    @Test
    fun `aggancia il punto medio di un segmento`() {
        val single = SnapEngine(listOf(CadLine(Vec2(0.0, 0.0), Vec2(10.0, 0.0))))
        val result = assertNotNull(
            single.snap(Vec2(5.2, 0.4), radius = 2.0, types = setOf(SnapType.MIDPOINT, SnapType.NEAREST)),
        )
        assertEquals(SnapType.MIDPOINT, result.type)
        assertTrue(result.point.isCloseTo(Vec2(5.0, 0.0), 1e-9))
    }

    @Test
    fun `aggancia centro e quadranti di un cerchio`() {
        val center = assertNotNull(engine.snap(Vec2(0.5, 100.5), radius = 3.0))
        assertEquals(SnapType.CENTER, center.type)

        val quadrant = assertNotNull(engine.snap(Vec2(10.4, 100.3), radius = 3.0))
        assertEquals(SnapType.QUADRANT, quadrant.type)
        assertTrue(quadrant.point.isCloseTo(Vec2(10.0, 100.0), 1e-9))
    }

    @Test
    fun `la perpendicolare parte dal punto gia scelto`() {
        val single = SnapEngine(listOf(CadLine(Vec2(0.0, 0.0), Vec2(10.0, 0.0))))
        val result = assertNotNull(
            single.snap(
                query = Vec2(4.6, 0.3),
                radius = 2.0,
                types = setOf(SnapType.PERPENDICULAR),
                from = Vec2(5.0, 8.0),
            ),
        )
        assertEquals(SnapType.PERPENDICULAR, result.type)
        assertTrue(result.point.isCloseTo(Vec2(5.0, 0.0), 1e-9))
    }

    @Test
    fun `fuori dal raggio di ricerca non aggancia nulla`() {
        assertNull(engine.snap(Vec2(500.0, 500.0), radius = 5.0))
    }

    @Test
    fun `aggancia anche i vertici delle polilinee con archi`() {
        val polyline = CadPolyline(
            vertices = listOf(
                PolylineVertex(Vec2(0.0, 0.0)),
                PolylineVertex(Vec2(10.0, 0.0), bulge = 1.0),
                PolylineVertex(Vec2(20.0, 0.0)),
            ),
        )
        val result = assertNotNull(
            SnapEngine(listOf(polyline)).snap(Vec2(10.3, 0.2), radius = 2.0, types = SnapType.ALL),
        )
        assertEquals(SnapType.ENDPOINT, result.type)
        assertTrue(result.point.isCloseTo(Vec2(10.0, 0.0), 1e-9))
    }

    @Test
    fun `il raggio di ricerca e in coordinate modello`() {
        // Stessa scena, tolleranza piu' stretta: l'aggancio deve sparire invece di allargarsi.
        assertNotNull(engine.snap(Vec2(4.0, 0.0), radius = 5.0, types = setOf(SnapType.ENDPOINT)))
        assertNull(engine.snap(Vec2(4.0, 0.0), radius = 2.0, types = setOf(SnapType.ENDPOINT)))
    }
}
