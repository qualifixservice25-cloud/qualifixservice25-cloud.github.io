package org.cadviewer.core.dimension

import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.measure.MeasurementFormatter
import org.cadviewer.core.measure.Tolerance
import org.cadviewer.core.model.DrawingUnits
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DimensionTest {

    private val style = DimensionStyle(
        textHeight = 2.5,
        arrowSize = 2.5,
        extensionOffset = 0.5,
        extensionOvershoot = 1.0,
        textGap = 0.5,
        precision = 1,
    )

    private val formatter = MeasurementFormatter(
        drawingUnits = DrawingUnits.MILLIMETERS,
        displayUnits = DrawingUnits.MILLIMETERS,
    )

    @Test
    fun `la quota orizzontale misura solo la componente in x`() {
        val dimension = LinearDimension(
            first = Vec2(0.0, 0.0),
            second = Vec2(100.0, 40.0),
            dimLinePoint = Vec2(0.0, -20.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style,
        )
        assertEquals(100.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `la quota verticale misura solo la componente in y`() {
        val dimension = LinearDimension(
            first = Vec2(0.0, 0.0),
            second = Vec2(100.0, 40.0),
            dimLinePoint = Vec2(-20.0, 0.0),
            orientation = LinearOrientation.VERTICAL,
            style = style,
        )
        assertEquals(40.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `la quota allineata misura la distanza reale`() {
        val dimension = LinearDimension(
            first = Vec2(0.0, 0.0),
            second = Vec2(30.0, 40.0),
            dimLinePoint = Vec2(-10.0, 10.0),
            orientation = LinearOrientation.ALIGNED,
            style = style,
        )
        assertEquals(50.0, dimension.measure(), 1e-9)
    }

    @Test
    fun `la linea di quota passa per il punto scelto dall utente`() {
        val dimension = LinearDimension(
            first = Vec2(0.0, 0.0),
            second = Vec2(100.0, 0.0),
            dimLinePoint = Vec2(0.0, 20.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style,
        )
        val geometry = dimension.geometry(formatter)
        val dimLine = geometry.segments.first()
        assertEquals(20.0, dimLine.start.y, 1e-9)
        assertEquals(20.0, dimLine.end.y, 1e-9)
        assertEquals(100.0, abs(dimLine.end.x - dimLine.start.x), 1e-9)
        assertEquals(2, geometry.arrows.size)
    }

    @Test
    fun `le linee di estensione si staccano dal punto rilevato e sporgono oltre la quota`() {
        val dimension = LinearDimension(
            first = Vec2(0.0, 0.0),
            second = Vec2(100.0, 0.0),
            dimLinePoint = Vec2(0.0, 20.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style,
        )
        val extensions = dimension.geometry(formatter).segments.drop(1)
        assertEquals(2, extensions.size)
        val first = extensions.first()
        assertEquals(0.5, first.start.y, 1e-9, "stacco DIMEXO dal punto rilevato")
        assertEquals(21.0, first.end.y, 1e-9, "sporgenza DIMEXE oltre la linea di quota")
    }

    @Test
    fun `il testo della quota non copre l oggetto misurato`() {
        val dimension = LinearDimension(
            first = Vec2(0.0, 0.0),
            second = Vec2(100.0, 0.0),
            dimLinePoint = Vec2(0.0, 20.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style,
        )
        val text = dimension.geometry(formatter).text
        assertTrue(text.position.y > 20.0, "il testo sta oltre la linea di quota, non sull'oggetto")
    }

    @Test
    fun `il testo resta leggibile anche su quote rovesciate`() {
        val dimension = LinearDimension(
            first = Vec2(100.0, 0.0),
            second = Vec2(0.0, 0.0),
            dimLinePoint = Vec2(0.0, 20.0),
            orientation = LinearOrientation.ALIGNED,
            style = style,
        )
        val rotation = dimension.geometry(formatter).text.rotationDeg
        assertTrue(rotation > -90.0 && rotation <= 90.0, "rotazione fuori scala di lettura: $rotation")
    }

    @Test
    fun `la quota angolare misura l angolo dalla parte in cui si posiziona l arco`() {
        val inner = AngularDimension(
            vertex = Vec2.ZERO,
            first = Vec2(10.0, 0.0),
            second = Vec2(0.0, 10.0),
            arcPoint = Vec2(5.0, 5.0),
            style = style,
        )
        assertEquals(90.0, inner.measure(), 1e-9)

        val outer = inner.copy(arcPoint = Vec2(-5.0, -5.0))
        assertEquals(
            270.0,
            outer.measure(),
            1e-9,
            "spostando l'arco dall'altra parte si quota l'angolo esplementare",
        )
    }

    @Test
    fun `la quota angolare disegna arco frecce e testo`() {
        val dimension = AngularDimension(
            vertex = Vec2.ZERO,
            first = Vec2(10.0, 0.0),
            second = Vec2(0.0, 10.0),
            arcPoint = Vec2(4.0, 4.0),
            style = style,
        )
        val geometry = dimension.geometry(formatter)
        assertEquals(1, geometry.arcs.size)
        assertEquals(2, geometry.arrows.size)
        assertEquals("90°", geometry.text.value)
    }

    @Test
    fun `raggio e diametro usano il prefisso giusto`() {
        val radius = RadialDimension(Vec2.ZERO, 25.0, angleDeg = 45.0, diameter = false, style = style)
        val diameter = radius.copy(diameter = true)

        assertEquals(25.0, radius.measure(), 1e-9)
        assertEquals(50.0, diameter.measure(), 1e-9)
        assertTrue(radius.text(formatter).startsWith("R"))
        assertTrue(diameter.text(formatter).startsWith("Ø"))
        assertEquals(2, diameter.geometry(formatter).arrows.size, "la quota diametrale ha due frecce")
        assertEquals(1, radius.geometry(formatter).arrows.size)
    }

    @Test
    fun `la quota ordinata misura rispetto all origine sull asse scelto`() {
        val alongX = OrdinateDimension(
            origin = Vec2(10.0, 10.0),
            feature = Vec2(85.0, 60.0),
            leaderEnd = Vec2(85.0, 90.0),
            axis = OrdinateAxis.X,
            style = style,
        )
        assertEquals(75.0, alongX.measure(), 1e-9)
        assertEquals(50.0, alongX.copy(axis = OrdinateAxis.Y).measure(), 1e-9)
    }

    @Test
    fun `il testo forzato dall utente sostituisce la misura`() {
        val dimension = LinearDimension(
            first = Vec2.ZERO,
            second = Vec2(100.0, 0.0),
            dimLinePoint = Vec2(0.0, 10.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style.copy(overrideText = "luce netta"),
        )
        assertEquals("luce netta", dimension.text(formatter))
        assertEquals(100.0, dimension.measure(), 1e-9, "la misura reale resta comunque disponibile")
    }

    @Test
    fun `la tolleranza compare nel testo della quota`() {
        val symmetric = LinearDimension(
            first = Vec2.ZERO,
            second = Vec2(100.0, 0.0),
            dimLinePoint = Vec2(0.0, 10.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style.copy(tolerance = Tolerance.symmetric(5.0)),
        )
        assertContains(symmetric.text(formatter), "±")

        val asymmetric = symmetric.copy(style = style.copy(tolerance = Tolerance(plus = 5.0, minus = 2.0)))
        val text = asymmetric.text(formatter)
        assertContains(text, "+5")
        assertContains(text, "-2")
    }

    @Test
    fun `le quote concatenate coprono tutti i tratti`() {
        val points = listOf(Vec2(0.0, 0.0), Vec2(80.0, 0.0), Vec2(200.0, 0.0), Vec2(260.0, 0.0))
        val chain = DimensionSeries.chained(
            points = points,
            dimLinePoint = Vec2(0.0, -30.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style,
        )
        assertEquals(listOf(80.0, 120.0, 60.0), chain.map { it.measure() })
    }

    @Test
    fun `le quote da linea base si impilano senza sovrapporsi`() {
        val base = Vec2(0.0, 0.0)
        val series = DimensionSeries.baseline(
            base = base,
            points = listOf(Vec2(80.0, 0.0), Vec2(200.0, 0.0), Vec2(260.0, 0.0)),
            firstDimLinePoint = Vec2(0.0, 30.0),
            orientation = LinearOrientation.HORIZONTAL,
            style = style,
        )
        assertEquals(listOf(80.0, 200.0, 260.0), series.map { it.measure() })

        val heights = series.map { it.geometry(formatter).segments.first().start.y }
        assertEquals(heights.distinct().size, heights.size, "ogni quota deve stare su una riga sua")
        assertTrue(heights.zipWithNext().all { (a, b) -> b > a }, "le quote si allontanano dall'oggetto")
    }

    @Test
    fun `lo stile si adatta alla dimensione del disegno`() {
        val small = DimensionStyle.forDrawing(org.cadviewer.core.geometry.Bounds(0.0, 0.0, 600.0, 300.0))
        val large = DimensionStyle.forDrawing(org.cadviewer.core.geometry.Bounds(0.0, 0.0, 60000.0, 30000.0))
        assertTrue(large.textHeight > small.textHeight * 50, "il testo deve scalare con il disegno")
    }
}
