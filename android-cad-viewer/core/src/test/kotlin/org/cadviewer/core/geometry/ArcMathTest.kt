package org.cadviewer.core.geometry

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ArcMathTest {

    @Test
    fun `bulge 1 descrive un semicerchio`() {
        val arc = assertNotNull(ArcMath.fromBulge(Vec2(0.0, 0.0), Vec2(10.0, 0.0), 1.0))
        assertEquals(5.0, arc.radius, 1e-9)
        assertTrue(arc.center.isCloseTo(Vec2(5.0, 0.0), 1e-9))
        assertEquals(180.0, arc.sweepDeg, 1e-9)
    }

    @Test
    fun `il segno del bulge decide da che parte curva l arco`() {
        val positive = assertNotNull(ArcMath.fromBulge(Vec2(0.0, 0.0), Vec2(10.0, 0.0), 0.5))
        val negative = assertNotNull(ArcMath.fromBulge(Vec2(0.0, 0.0), Vec2(10.0, 0.0), -0.5))
        assertEquals(positive.radius, negative.radius, 1e-9)
        assertTrue(
            positive.center.y > 0 && negative.center.y < 0,
            "i due archi devono avere il centro su lati opposti della corda",
        )
        // Entrambi restano archi antiorari, come vuole la convenzione DXF.
        assertEquals(positive.sweepDeg, negative.sweepDeg, 1e-9)
    }

    @Test
    fun `un bulge nullo non genera archi`() {
        assertNull(ArcMath.fromBulge(Vec2(0.0, 0.0), Vec2(10.0, 0.0), 0.0))
    }

    @Test
    fun `l ingombro di un arco conta solo i quadranti attraversati`() {
        val quarter = ArcMath.arcBounds(Vec2.ZERO, 1.0, 0.0, 90.0)
        assertEquals(0.0, quarter.minX, 1e-9)
        assertEquals(0.0, quarter.minY, 1e-9)
        assertEquals(1.0, quarter.maxX, 1e-9)
        assertEquals(1.0, quarter.maxY, 1e-9)

        val threeQuarters = ArcMath.arcBounds(Vec2.ZERO, 1.0, 0.0, 270.0)
        assertEquals(-1.0, threeQuarters.minX, 1e-9)
        assertEquals(-1.0, threeQuarters.minY, 1e-9)
    }

    @Test
    fun `l ampiezza di un arco chiuso su se stesso e il giro completo`() {
        assertEquals(360.0, ArcMath.sweepDeg(0.0, 0.0), 1e-9)
        assertEquals(90.0, ArcMath.sweepDeg(350.0, 80.0), 1e-9)
    }

    @Test
    fun `la lunghezza dell arco segue il raggio`() {
        val arc = ArcSegment(Vec2.ZERO, 2.0, 0.0, 180.0)
        assertTrue(abs(arc.length - Math.PI * 2.0) < 1e-9)
    }
}
