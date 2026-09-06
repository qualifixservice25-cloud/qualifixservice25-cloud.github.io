package org.cadviewer.core.dimension

import org.cadviewer.core.geometry.ArcSegment
import org.cadviewer.core.geometry.Bounds
import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.measure.Tolerance
import org.cadviewer.core.model.TextHorizontalAlign

/**
 * Stile di quotatura. I nomi fra parentesi sono le variabili DIMSTYLE del DXF: tenerli
 * allineati rende immediato leggere lo stile di un disegno esistente e riprodurlo qui.
 *
 * Tutte le grandezze grafiche sono in unita' del disegno e vengono moltiplicate per [scale]
 * (DIMSCALE), che e' cio' che l'app regola quando la quota risulta minuscola su una tavola
 * disegnata in metri o gigantesca su un dettaglio in millimetri.
 */
data class DimensionStyle(
    /** Altezza del testo (DIMTXT). */
    val textHeight: Double = 2.5,
    /** Lunghezza della punta di freccia (DIMASZ). */
    val arrowSize: Double = 2.5,
    /** Stacco della linea di estensione dal punto rilevato (DIMEXO). */
    val extensionOffset: Double = 0.625,
    /** Sporgenza della linea di estensione oltre la linea di quota (DIMEXE). */
    val extensionOvershoot: Double = 1.25,
    /** Distanza fra testo e linea di quota (DIMGAP). */
    val textGap: Double = 0.625,
    /** Decimali della quota lineare (DIMDEC). */
    val precision: Int = 2,
    /** Decimali della quota angolare (DIMADEC). */
    val angularPrecision: Int = 0,
    /** Fattore di scala di tutte le grandezze grafiche (DIMSCALE). */
    val scale: Double = 1.0,
    val tolerance: Tolerance? = null,
    /** Testo imposto dall'utente al posto della misura calcolata. */
    val overrideText: String? = null,
    val layer: String = QUOTE_LAYER,
) {
    val effectiveTextHeight: Double get() = textHeight * scale
    val effectiveArrowSize: Double get() = arrowSize * scale
    val effectiveExtensionOffset: Double get() = extensionOffset * scale
    val effectiveExtensionOvershoot: Double get() = extensionOvershoot * scale
    val effectiveTextGap: Double get() = textGap * scale

    companion object {
        /**
         * Layer su cui l'app scrive le proprie quote. Restare su un layer dedicato e'
         * quello che permette di spegnerle in blocco e di non confonderle mai con il
         * disegno originale.
         */
        const val QUOTE_LAYER = "QUOTE_APP"

        /**
         * Stile proporzionato all'ingombro del disegno: una quota dimensionata per una
         * tavola in millimetri sparisce su un rilievo in metri, e viceversa.
         */
        fun forDrawing(bounds: Bounds): DimensionStyle {
            if (bounds.isEmpty) return DimensionStyle()
            val diagonal = maxOf(bounds.width, bounds.height)
            val textHeight = (diagonal / 60.0).coerceAtLeast(1e-6)
            return DimensionStyle(
                textHeight = textHeight,
                arrowSize = textHeight,
                extensionOffset = textHeight * 0.25,
                extensionOvershoot = textHeight * 0.5,
                textGap = textHeight * 0.25,
            )
        }
    }
}

/** Segmento di disegno prodotto dal motore di quotatura. */
data class DimSegment(val start: Vec2, val end: Vec2)

/** Punta di freccia piena: [tip] e' il vertice, [base] i due punti della base. */
data class Arrowhead(val tip: Vec2, val base: Pair<Vec2, Vec2>) {
    val points: List<Vec2> get() = listOf(tip, base.first, base.second)
}

data class DimensionText(
    val value: String,
    val position: Vec2,
    val height: Double,
    val rotationDeg: Double,
    val align: TextHorizontalAlign = TextHorizontalAlign.CENTER,
)

/**
 * Geometria completa di una quota, in coordinate modello. Il renderer non deve sapere nulla
 * di quotature: riceve segmenti, triangoli, archi e un testo gia' posizionato. E' anche cio'
 * che rende il motore testabile senza Android.
 */
data class DimensionGeometry(
    val segments: List<DimSegment> = emptyList(),
    val arrows: List<Arrowhead> = emptyList(),
    val arcs: List<ArcSegment> = emptyList(),
    val text: DimensionText,
) {
    val bounds: Bounds
        get() {
            var bounds = Bounds.EMPTY
            segments.forEach { bounds = bounds.include(it.start).include(it.end) }
            arrows.forEach { arrow -> arrow.points.forEach { bounds = bounds.include(it) } }
            arcs.forEach { bounds = bounds.union(it.bounds) }
            val halfWidth = text.value.length * text.height * 0.3
            bounds = bounds
                .include(text.position + Vec2(-halfWidth, -text.height))
                .include(text.position + Vec2(halfWidth, text.height))
            return bounds
        }
}
