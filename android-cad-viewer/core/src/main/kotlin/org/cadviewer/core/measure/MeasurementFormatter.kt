package org.cadviewer.core.measure

import org.cadviewer.core.model.DrawingUnits
import java.util.Locale
import kotlin.math.abs

/**
 * Tolleranza di una quota. Simmetrica (`±5`) quando i due scarti coincidono, altrimenti
 * scritta sulle due righe `+a` / `-b` come nelle tavole di officina.
 */
data class Tolerance(val plus: Double, val minus: Double) {
    val isSymmetric: Boolean get() = abs(plus - minus) < 1e-12

    companion object {
        fun symmetric(value: Double) = Tolerance(abs(value), abs(value))
    }
}

/**
 * Trasforma una misura in coordinate modello nel testo che finisce sulla quota.
 *
 * La conversione fra unita' e' il punto in cui un'app di cantiere sbaglia in modo silenzioso:
 * se il disegno e' in millimetri e l'utente legge metri senza saperlo, il numero e' comunque
 * plausibile. Per questo quando il disegno non dichiara le unita' ([DrawingUnits.UNITLESS])
 * qui non si converte nulla e il valore resta grezzo.
 */
class MeasurementFormatter(
    val drawingUnits: DrawingUnits = DrawingUnits.UNITLESS,
    val displayUnits: DrawingUnits = drawingUnits,
    val linearPrecision: Int = 2,
    val angularPrecision: Int = 0,
    val showUnitSuffix: Boolean = true,
    /** Elimina gli zeri decimali finali, come `DIMZIN` nei CAD desktop. */
    val suppressTrailingZeros: Boolean = false,
    val locale: Locale = Locale.ROOT,
) {

    /** Fattore applicato alle misure; 1.0 quando la conversione non e' possibile o non serve. */
    val conversionFactor: Double =
        drawingUnits.conversionFactorTo(displayUnits) ?: 1.0

    /** True se le unita' richieste non sono ottenibili da quelle del disegno. */
    val conversionUnavailable: Boolean =
        drawingUnits != displayUnits && drawingUnits.conversionFactorTo(displayUnits) == null

    val unitSuffix: String
        get() = when {
            !showUnitSuffix -> ""
            conversionUnavailable || displayUnits == DrawingUnits.UNITLESS -> ""
            else -> " ${displayUnits.abbreviation}"
        }

    fun convert(modelValue: Double): Double = modelValue * conversionFactor

    /**
     * Testo di una quota lineare: prefisso (`R`, `Ø`), valore convertito, suffisso di unita'
     * ed eventuale tolleranza.
     */
    fun formatLinear(
        modelValue: Double,
        prefix: String = "",
        tolerance: Tolerance? = null,
    ): String {
        val value = number(convert(modelValue), linearPrecision)
        val base = "$prefix$value$unitSuffix"
        if (tolerance == null) return base
        return when {
            tolerance.isSymmetric ->
                "$base ±${number(convert(tolerance.plus), linearPrecision)}"

            else -> {
                val plus = number(convert(tolerance.plus), linearPrecision)
                val minus = number(convert(tolerance.minus), linearPrecision)
                "$base +$plus/-$minus"
            }
        }
    }

    fun formatAngle(degrees: Double): String = "${number(degrees, angularPrecision)}°"

    /** Angolo in gradi, primi e secondi: usato per le quote angolari nei rilievi topografici. */
    fun formatAngleDms(degrees: Double): String {
        val sign = if (degrees < 0) "-" else ""
        val total = abs(degrees)
        val d = total.toInt()
        val minutesTotal = (total - d) * 60.0
        val m = minutesTotal.toInt()
        val s = (minutesTotal - m) * 60.0
        return "$sign$d°$m'${number(s, 0)}\""
    }

    private fun number(value: Double, precision: Int): String {
        val decimals = precision.coerceIn(0, 8)
        var text = String.format(locale, "%.${decimals}f", value)
        // "-0,00" e' matematicamente corretto e visivamente sbagliato su una quota.
        if (text.startsWith("-") && text.drop(1).all { it == '0' || it == '.' || it == ',' }) {
            text = text.drop(1)
        }
        if (!suppressTrailingZeros || decimals == 0) return text
        val separator = if (text.contains(',')) ',' else '.'
        if (!text.contains(separator)) return text
        return text.trimEnd('0').trimEnd(separator)
    }

    fun withDisplayUnits(units: DrawingUnits): MeasurementFormatter = MeasurementFormatter(
        drawingUnits = drawingUnits,
        displayUnits = units,
        linearPrecision = linearPrecision,
        angularPrecision = angularPrecision,
        showUnitSuffix = showUnitSuffix,
        suppressTrailingZeros = suppressTrailingZeros,
        locale = locale,
    )

    fun withPrecision(linear: Int = linearPrecision, angular: Int = angularPrecision): MeasurementFormatter =
        MeasurementFormatter(
            drawingUnits = drawingUnits,
            displayUnits = displayUnits,
            linearPrecision = linear,
            angularPrecision = angular,
            showUnitSuffix = showUnitSuffix,
            suppressTrailingZeros = suppressTrailingZeros,
            locale = locale,
        )
}
