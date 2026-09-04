package org.qualifix.cad.core.model

import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Conversione dall'AutoCAD Color Index al colore RGB.
 *
 * I primi nove indici sono la tavolozza fissa che compare praticamente su ogni tavola edile
 * (rosso = murature nuove, giallo = demolizioni, e cosi' via a seconda dello studio) e sono
 * riportati esatti. Gli indici 10-249 seguono la rampa a 24 tinte per 10 gradazioni: qui sono
 * ricostruiti per approssimazione, sufficiente per la lettura a schermo. 250-255 sono i grigi.
 */
object AciPalette {

    private val FIXED: Map<Int, Int> = mapOf(
        1 to 0xFF0000, // rosso
        2 to 0xFFFF00, // giallo
        3 to 0x00FF00, // verde
        4 to 0x00FFFF, // ciano
        5 to 0x0000FF, // blu
        6 to 0xFF00FF, // magenta
        7 to 0xFFFFFF, // bianco su fondo scuro, nero su fondo chiaro
        8 to 0x808080,
        9 to 0xC0C0C0,
        250 to 0x333333,
        251 to 0x505050,
        252 to 0x696969,
        253 to 0x828282,
        254 to 0xBEBEBE,
        255 to 0xFFFFFF,
    )

    /**
     * Colore RGB (0xRRGGBB) dell'indice ACI. L'indice 7 e' il caso speciale del CAD: significa
     * "colore di primo piano", quindi dipende dal fondo su cui si disegna.
     */
    fun rgb(index: Int, darkBackground: Boolean = true): Int {
        if (index == 7) return if (darkBackground) 0xFFFFFF else 0x000000
        FIXED[index]?.let { return it }
        if (index < 10 || index > 249) return if (darkBackground) 0xFFFFFF else 0x000000

        val offset = index - 10
        val hue = (offset / 10) * 15.0
        val shade = offset % 10
        // Gradazioni pari: tinta piena che si scurisce. Dispari: stessa tinta smorzata.
        val value = 1.0 - (shade / 2) * 0.18
        val saturation = if (shade % 2 == 0) 1.0 else 0.5
        return hsvToRgb(hue, saturation, value.coerceIn(0.15, 1.0))
    }

    /** Colore effettivo di un'entita', risolvendo BYLAYER e BYBLOCK. */
    fun resolve(entityColor: AciColor, layerColor: AciColor, darkBackground: Boolean = true): Int {
        val index = when {
            entityColor.isByLayer || entityColor.isByBlock -> layerColor.index
            else -> entityColor.index
        }
        return rgb(index, darkBackground)
    }

    private fun hsvToRgb(hueDeg: Double, saturation: Double, value: Double): Int {
        val h = (hueDeg % 360.0) / 60.0
        val c = value * saturation
        val x = c * (1 - abs(h % 2 - 1))
        val m = value - c
        val (r, g, b) = when (h.toInt()) {
            0 -> Triple(c, x, 0.0)
            1 -> Triple(x, c, 0.0)
            2 -> Triple(0.0, c, x)
            3 -> Triple(0.0, x, c)
            4 -> Triple(x, 0.0, c)
            else -> Triple(c, 0.0, x)
        }
        val red = ((r + m) * 255).roundToInt().coerceIn(0, 255)
        val green = ((g + m) * 255).roundToInt().coerceIn(0, 255)
        val blue = ((b + m) * 255).roundToInt().coerceIn(0, 255)
        return (red shl 16) or (green shl 8) or blue
    }
}
