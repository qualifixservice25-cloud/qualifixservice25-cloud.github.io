package org.qualifix.cad.core.geometry

import kotlin.math.max
import kotlin.math.min

/**
 * Rettangolo di ingombro allineato agli assi. Serve al culling in fase di rendering e allo
 * zoom "fit to drawing": senza un ingombro affidabile lo zoom iniziale finisce fuori dal foglio.
 */
data class Bounds(
    val minX: Double,
    val minY: Double,
    val maxX: Double,
    val maxY: Double,
) {
    val width: Double get() = maxX - minX
    val height: Double get() = maxY - minY
    val center: Vec2 get() = Vec2((minX + maxX) / 2.0, (minY + maxY) / 2.0)
    val isEmpty: Boolean get() = minX > maxX || minY > maxY

    fun union(other: Bounds): Bounds = when {
        other.isEmpty -> this
        isEmpty -> other
        else -> Bounds(
            min(minX, other.minX),
            min(minY, other.minY),
            max(maxX, other.maxX),
            max(maxY, other.maxY),
        )
    }

    fun include(point: Vec2): Bounds = when {
        isEmpty -> Bounds(point.x, point.y, point.x, point.y)
        else -> Bounds(
            min(minX, point.x),
            min(minY, point.y),
            max(maxX, point.x),
            max(maxY, point.y),
        )
    }

    fun intersects(other: Bounds): Boolean =
        !isEmpty && !other.isEmpty &&
            minX <= other.maxX && maxX >= other.minX &&
            minY <= other.maxY && maxY >= other.minY

    fun contains(point: Vec2): Boolean =
        !isEmpty && point.x in minX..maxX && point.y in minY..maxY

    /** Allarga di [margin] su ogni lato. Con margine negativo il risultato puo' diventare vuoto. */
    fun inflate(margin: Double): Bounds =
        if (isEmpty) this else Bounds(minX - margin, minY - margin, maxX + margin, maxY + margin)

    companion object {
        /** Ingombro vuoto: assorbito da qualsiasi union, cosi' si puo' usare come accumulatore. */
        val EMPTY = Bounds(
            Double.POSITIVE_INFINITY,
            Double.POSITIVE_INFINITY,
            Double.NEGATIVE_INFINITY,
            Double.NEGATIVE_INFINITY,
        )

        fun of(points: Iterable<Vec2>): Bounds =
            points.fold(EMPTY) { acc, p -> acc.include(p) }

        fun of(vararg points: Vec2): Bounds = of(points.asIterable())
    }
}
