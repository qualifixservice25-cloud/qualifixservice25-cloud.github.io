package org.cadviewer.core.tool

import org.cadviewer.core.dimension.AngularDimension
import org.cadviewer.core.dimension.LinearDimension
import org.cadviewer.core.dimension.LinearOrientation
import org.cadviewer.core.dimension.OrdinateAxis
import org.cadviewer.core.dimension.OrdinateDimension
import org.cadviewer.core.dimension.RadialDimension
import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.model.CadArc
import org.cadviewer.core.model.CadCircle
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DimensionBuilderTest {

    @Test
    fun `senza abbastanza punti non nasce nessuna quota`() {
        assertNull(DimensionBuilder.build(CadTool.LINEAR, listOf(Vec2.ZERO, Vec2(10.0, 0.0))))
        assertNull(DimensionBuilder.build(CadTool.ANGULAR, listOf(Vec2.ZERO)))
    }

    @Test
    fun `trascinando la quota verso l alto si misura la distanza orizzontale`() {
        val dimension = assertIs<LinearDimension>(
            DimensionBuilder.build(
                tool = CadTool.LINEAR,
                points = listOf(Vec2(0.0, 0.0), Vec2(100.0, 20.0), Vec2(50.0, 80.0)),
            ),
        )
        assertEquals(LinearOrientation.HORIZONTAL, dimension.orientation)
        assertEquals(100.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `trascinando la quota di lato si misura la distanza verticale`() {
        val dimension = assertIs<LinearDimension>(
            DimensionBuilder.build(
                tool = CadTool.LINEAR,
                points = listOf(Vec2(0.0, 0.0), Vec2(100.0, 20.0), Vec2(180.0, 10.0)),
            ),
        )
        assertEquals(LinearOrientation.VERTICAL, dimension.orientation)
        assertEquals(20.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `la quota allineata resta allineata comunque la si trascini`() {
        val dimension = assertIs<LinearDimension>(
            DimensionBuilder.build(
                tool = CadTool.ALIGNED,
                points = listOf(Vec2(0.0, 0.0), Vec2(30.0, 40.0), Vec2(-20.0, 20.0)),
            ),
        )
        assertEquals(LinearOrientation.ALIGNED, dimension.orientation)
        assertEquals(50.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `la misura rapida appoggia la quota sul segmento misurato`() {
        val dimension = assertIs<LinearDimension>(
            DimensionBuilder.build(CadTool.MEASURE, listOf(Vec2(0.0, 0.0), Vec2(60.0, 80.0))),
        )
        assertEquals(100.0, dimension.measure(), 1e-9)
        assertTrue(dimension.dimLinePoint.isCloseTo(Vec2(30.0, 40.0), 1e-9))
    }

    @Test
    fun `la quota angolare usa i quattro punti nell ordine di raccolta`() {
        val dimension = assertIs<AngularDimension>(
            DimensionBuilder.build(
                tool = CadTool.ANGULAR,
                points = listOf(Vec2.ZERO, Vec2(10.0, 0.0), Vec2(0.0, 10.0), Vec2(3.0, 3.0)),
            ),
        )
        assertEquals(90.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `la quota radiale aggancia il cerchio toccato`() {
        val entities = listOf(
            CadCircle(Vec2(0.0, 0.0), 10.0),
            CadCircle(Vec2(500.0, 500.0), 3.0),
        )
        val dimension = assertIs<RadialDimension>(
            DimensionBuilder.build(
                tool = CadTool.RADIUS,
                points = listOf(Vec2(9.6, 0.2), Vec2(20.0, 0.0)),
                entities = entities,
            ),
        )
        assertEquals(10.0, dimension.measure(), 1e-9)
        assertTrue(dimension.center.isCloseTo(Vec2.ZERO, 1e-9))
        assertEquals(false, dimension.diameter)
    }

    @Test
    fun `la quota diametrale raddoppia la misura del raggio`() {
        val entities = listOf(CadArc(Vec2(0.0, 0.0), 25.0, 0.0, 180.0))
        val dimension = assertIs<RadialDimension>(
            DimensionBuilder.build(
                tool = CadTool.DIAMETER,
                points = listOf(Vec2(0.0, 24.5), Vec2(0.0, 40.0)),
                entities = entities,
            ),
        )
        assertEquals(50.0, dimension.measure(), 1e-9)
        assertEquals(true, dimension.diameter)
    }

    @Test
    fun `senza cerchi vicini la quota radiale non viene creata`() {
        val entities = listOf(CadCircle(Vec2(500.0, 500.0), 3.0))
        assertNull(
            DimensionBuilder.build(
                tool = CadTool.RADIUS,
                points = listOf(Vec2(0.0, 0.0), Vec2(10.0, 0.0)),
                entities = entities,
                circularTolerance = 5.0,
            ),
        )
    }

    @Test
    fun `il verso del richiamo decide l asse della quota ordinata`() {
        val vertical = assertIs<OrdinateDimension>(
            DimensionBuilder.build(
                tool = CadTool.ORDINATE,
                points = listOf(Vec2(0.0, 0.0), Vec2(75.0, 20.0), Vec2(75.0, 90.0)),
            ),
        )
        assertEquals(OrdinateAxis.X, vertical.axis)
        assertEquals(75.0, vertical.measure(), 1e-9)

        val horizontal = assertIs<OrdinateDimension>(
            DimensionBuilder.build(
                tool = CadTool.ORDINATE,
                points = listOf(Vec2(0.0, 0.0), Vec2(75.0, 20.0), Vec2(160.0, 20.0)),
            ),
        )
        assertEquals(OrdinateAxis.Y, horizontal.axis)
        assertEquals(20.0, horizontal.measure(), 1e-9)
    }

    @Test
    fun `individua l arco piu vicino al punto toccato`() {
        val target = assertNotNull(
            DimensionBuilder.findCircular(
                entities = listOf(
                    CadCircle(Vec2(0.0, 0.0), 10.0),
                    CadCircle(Vec2(0.0, 0.0), 40.0),
                ),
                near = Vec2(38.0, 0.0),
            ),
        )
        assertEquals(40.0, target.radius, 1e-9)
    }

    @Test
    fun `toccare il centro seleziona comunque il cerchio`() {
        val target = assertNotNull(
            DimensionBuilder.findCircular(
                entities = listOf(CadCircle(Vec2(10.0, 10.0), 4.0)),
                near = Vec2(10.2, 10.1),
                tolerance = 2.0,
            ),
        )
        assertEquals(4.0, target.radius, 1e-9)
    }

    @Test
    fun `lo strumento di spostamento non richiede tocchi`() {
        assertEquals(0, CadTool.PAN.requiredPoints)
        assertTrue(CadTool.LINEAR.isDimensionTool)
        assertTrue(!CadTool.MEASURE.isDimensionTool, "la misura rapida non lascia quote sul disegno")
    }
}
