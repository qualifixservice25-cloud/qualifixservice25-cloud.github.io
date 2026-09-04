package org.qualifix.cad.core.model

/**
 * Unita' del disegno, dalla variabile di header `$INSUNITS` del DXF.
 *
 * E' il dato piu' delicato dell'intera app: se viene interpretato male le quote mostrano
 * numeri plausibili ma sbagliati, senza nessun errore visibile. Per questo il valore letto
 * viene sempre esposto all'utente nella barra di stato, incluso il caso [UNITLESS], dove il
 * disegno non dichiara alcuna unita' e nessuna conversione e' legittima.
 */
enum class DrawingUnits(
    val code: Int,
    val abbreviation: String,
    /** Fattore di conversione verso il millimetro; null quando la conversione non ha senso. */
    val millimetersPerUnit: Double?,
) {
    UNITLESS(0, "u", null),
    INCHES(1, "in", 25.4),
    FEET(2, "ft", 304.8),
    MILES(3, "mi", 1_609_344.0),
    MILLIMETERS(4, "mm", 1.0),
    CENTIMETERS(5, "cm", 10.0),
    METERS(6, "m", 1000.0),
    KILOMETERS(7, "km", 1_000_000.0),
    MICROINCHES(8, "µin", 25.4e-6),
    MILS(9, "mil", 0.0254),
    YARDS(10, "yd", 914.4),
    ANGSTROMS(11, "Å", 1e-7),
    NANOMETERS(12, "nm", 1e-6),
    MICRONS(13, "µm", 1e-3),
    DECIMETERS(14, "dm", 100.0),
    DECAMETERS(15, "dam", 10_000.0),
    HECTOMETERS(16, "hm", 100_000.0),
    GIGAMETERS(17, "Gm", 1e12),
    ASTRONOMICAL_UNITS(18, "AU", 1.495978707e14),
    LIGHT_YEARS(19, "ly", 9.4607304725808e18),
    PARSECS(20, "pc", 3.0856775814913673e19),
    ;

    val isMetric: Boolean
        get() = this in setOf(MILLIMETERS, CENTIMETERS, DECIMETERS, METERS, KILOMETERS)

    /**
     * Fattore per convertire una misura da questa unita' a [target].
     * Null se una delle due e' [UNITLESS]: in quel caso l'app mostra il valore grezzo
     * invece di inventare una conversione.
     */
    fun conversionFactorTo(target: DrawingUnits): Double? {
        val from = millimetersPerUnit ?: return null
        val to = target.millimetersPerUnit ?: return null
        return from / to
    }

    companion object {
        fun fromCode(code: Int): DrawingUnits =
            entries.firstOrNull { it.code == code } ?: UNITLESS

        /** Unita' proposte in interfaccia per un disegno metrico: le sole usate in cantiere. */
        val COMMON_METRIC = listOf(MILLIMETERS, CENTIMETERS, METERS)
    }
}
