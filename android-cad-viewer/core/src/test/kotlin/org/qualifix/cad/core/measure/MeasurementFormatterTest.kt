package org.qualifix.cad.core.measure

import org.qualifix.cad.core.model.DrawingUnits
import java.util.Locale
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class MeasurementFormatterTest {

    @Test
    fun `converte fra unita metriche`() {
        val formatter = MeasurementFormatter(
            drawingUnits = DrawingUnits.MILLIMETERS,
            displayUnits = DrawingUnits.METERS,
            linearPrecision = 2,
        )
        assertEquals("2.50 m", formatter.formatLinear(2500.0))
        assertEquals(2.5, formatter.convert(2500.0), 1e-12)
    }

    @Test
    fun `un disegno senza unita non viene convertito`() {
        val formatter = MeasurementFormatter(
            drawingUnits = DrawingUnits.UNITLESS,
            displayUnits = DrawingUnits.METERS,
            linearPrecision = 1,
        )
        assertTrue(formatter.conversionUnavailable, "senza unita' dichiarate non esiste conversione lecita")
        assertEquals(1.0, formatter.conversionFactor)
        assertEquals("2500.0", formatter.formatLinear(2500.0), "il valore resta quello del disegno")
    }

    @Test
    fun `da pollici a millimetri`() {
        val formatter = MeasurementFormatter(
            drawingUnits = DrawingUnits.INCHES,
            displayUnits = DrawingUnits.MILLIMETERS,
            linearPrecision = 1,
        )
        assertEquals("25.4 mm", formatter.formatLinear(1.0))
    }

    @Test
    fun `la tolleranza simmetrica usa il simbolo piu meno`() {
        val formatter = MeasurementFormatter(DrawingUnits.MILLIMETERS, linearPrecision = 0)
        assertEquals("120 mm ±5", formatter.formatLinear(120.0, tolerance = Tolerance.symmetric(5.0)))
    }

    @Test
    fun `la tolleranza asimmetrica riporta i due scarti`() {
        val formatter = MeasurementFormatter(DrawingUnits.MILLIMETERS, linearPrecision = 0)
        assertEquals(
            "120 mm +5/-2",
            formatter.formatLinear(120.0, tolerance = Tolerance(plus = 5.0, minus = 2.0)),
        )
    }

    @Test
    fun `una misura quasi nulla non diventa meno zero`() {
        val formatter = MeasurementFormatter(DrawingUnits.MILLIMETERS, linearPrecision = 2, showUnitSuffix = false)
        assertEquals("0.00", formatter.formatLinear(-0.0004))
        assertFalse(formatter.formatLinear(-0.0004).startsWith("-"))
    }

    @Test
    fun `gli zeri finali si possono sopprimere`() {
        val fixed = MeasurementFormatter(DrawingUnits.MILLIMETERS, linearPrecision = 3, showUnitSuffix = false)
        val trimmed = MeasurementFormatter(
            drawingUnits = DrawingUnits.MILLIMETERS,
            linearPrecision = 3,
            showUnitSuffix = false,
            suppressTrailingZeros = true,
        )
        assertEquals("2.500", fixed.formatLinear(2.5))
        assertEquals("2.5", trimmed.formatLinear(2.5))
        assertEquals("3", trimmed.formatLinear(3.0))
    }

    @Test
    fun `segue le convenzioni locali per il separatore decimale`() {
        val italian = MeasurementFormatter(
            drawingUnits = DrawingUnits.METERS,
            linearPrecision = 2,
            showUnitSuffix = false,
            locale = Locale.ITALY,
        )
        assertEquals("2,50", italian.formatLinear(2.5), "in cantiere in Italia si scrive con la virgola")
    }

    @Test
    fun `formatta gli angoli in gradi e in gradi primi secondi`() {
        val formatter = MeasurementFormatter(DrawingUnits.MILLIMETERS, angularPrecision = 1)
        assertEquals("45.5°", formatter.formatAngle(45.5))
        assertEquals("45°30'0\"", formatter.formatAngleDms(45.5))
    }

    @Test
    fun `il suffisso di unita si puo togliere`() {
        val formatter = MeasurementFormatter(
            drawingUnits = DrawingUnits.CENTIMETERS,
            linearPrecision = 0,
            showUnitSuffix = false,
        )
        assertEquals("42", formatter.formatLinear(42.0))
    }
}
