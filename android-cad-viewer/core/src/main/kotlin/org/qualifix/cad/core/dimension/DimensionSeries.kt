package org.qualifix.cad.core.dimension

import org.qualifix.cad.core.geometry.Vec2

/**
 * Serie di quote: le due forme che in cantiere si usano davvero quando i punti da quotare
 * sono piu' di due.
 *
 * - **Concatenate** (continue): ogni quota riparte dove finisce la precedente, tutte sulla
 *   stessa linea. E' come si quota una parete con piu' aperture.
 * - **Da linea base** (baseline): tutte le quote partono dallo stesso punto e si impilano
 *   una sopra l'altra. E' come si riportano le posizioni rispetto a un filo fisso.
 */
object DimensionSeries {

    /**
     * Quote concatenate lungo [points], tutte sulla linea passante per [dimLinePoint].
     * Restituisce una lista vuota con meno di due punti.
     */
    fun chained(
        points: List<Vec2>,
        dimLinePoint: Vec2,
        orientation: LinearOrientation = LinearOrientation.ALIGNED,
        style: DimensionStyle = DimensionStyle(),
    ): List<LinearDimension> {
        if (points.size < 2) return emptyList()
        return points.zipWithNext { a, b ->
            LinearDimension(
                first = a,
                second = b,
                dimLinePoint = dimLinePoint,
                orientation = orientation,
                style = style,
            )
        }
    }

    /**
     * Quote a partire da [base], impilate con passo [spacing] nella direzione che si allontana
     * dall'oggetto. Il passo di default (due volte l'altezza del testo piu' il gap) e' quello
     * che impedisce alle quote di sovrapporsi, che e' il difetto tipico delle serie generate
     * automaticamente.
     */
    fun baseline(
        base: Vec2,
        points: List<Vec2>,
        firstDimLinePoint: Vec2,
        orientation: LinearOrientation = LinearOrientation.ALIGNED,
        style: DimensionStyle = DimensionStyle(),
        spacing: Double = style.effectiveTextHeight * 2 + style.effectiveTextGap,
    ): List<LinearDimension> {
        if (points.isEmpty()) return emptyList()

        val reference = LinearDimension(base, points.first(), firstDimLinePoint, orientation, style)
        // Direzione di impilamento: perpendicolare alla linea di quota, allontanandosi
        // dal punto base.
        val normal = reference.direction.leftNormal
        val awayFromBase = if ((firstDimLinePoint - base).dot(normal) >= 0) normal else -normal

        return points.mapIndexed { index, point ->
            LinearDimension(
                first = base,
                second = point,
                dimLinePoint = firstDimLinePoint + awayFromBase * (spacing * index),
                orientation = orientation,
                style = style,
            )
        }
    }
}
