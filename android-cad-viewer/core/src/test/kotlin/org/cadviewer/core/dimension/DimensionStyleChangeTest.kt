package org.cadviewer.core.dimension

import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.measure.MeasurementFormatter
import org.cadviewer.core.model.DrawingUnits
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Cambio di stile a disegno gia' quotato: e' l'operazione che l'utente fa dalla barra di stato
 * quando decide che i millimetri con due decimali sono illeggibili sul telefono.
 */
class DimensionStyleChangeTest {

    private val formatter = MeasurementFormatter(DrawingUnits.MILLIMETERS)

    @Test
    fun `cambiare i decimali riscrive il testo di tutte le quote`() {
        val dimensions = listOf(
            LinearDimension(
                first = Vec2.ZERO,
                second = Vec2(1234.5, 0.0),
                dimLinePoint = Vec2(0.0, 100.0),
                orientation = LinearOrientation.HORIZONTAL,
                style = DimensionStyle(precision = 2),
            ),
            RadialDimension(Vec2.ZERO, 250.4, angleDeg = 0.0, style = DimensionStyle(precision = 2)),
        )
        assertEquals(listOf("1234.50 mm", "R250.40 mm"), dimensions.map { it.text(formatter) })

        val rounded = dimensions.map { it.withStyle(it.style.copy(precision = 0)) }
        assertEquals(listOf("1235 mm", "R250 mm"), rounded.map { it.text(formatter) })
    }

    @Test
    fun `il cambio di stile non tocca la misura ne l identita della quota`() {
        val dimension = LinearDimension(
            first = Vec2.ZERO,
            second = Vec2(100.0, 0.0),
            dimLinePoint = Vec2(0.0, 20.0),
            orientation = LinearOrientation.HORIZONTAL,
        )
        val restyled = dimension.withStyle(dimension.style.copy(scale = 4.0))

        assertEquals(dimension.measure(), restyled.measure(), 1e-12)
        assertEquals(dimension.id, restyled.id, "la quota resta la stessa, cambia solo come si vede")
        assertEquals(
            dimension.style.textHeight * 4.0,
            restyled.style.effectiveTextHeight,
            1e-12,
        )
    }
}
