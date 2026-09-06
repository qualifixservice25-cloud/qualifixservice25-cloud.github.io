package org.cadviewer.core.geometry

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/** Punto o vettore nello spazio modello del disegno (coordinate CAD, non pixel). */
data class Vec2(val x: Double, val y: Double) {

    operator fun plus(other: Vec2) = Vec2(x + other.x, y + other.y)

    operator fun minus(other: Vec2) = Vec2(x - other.x, y - other.y)

    operator fun times(factor: Double) = Vec2(x * factor, y * factor)

    operator fun div(factor: Double) = Vec2(x / factor, y / factor)

    operator fun unaryMinus() = Vec2(-x, -y)

    val length: Double get() = hypot(x, y)

    val lengthSquared: Double get() = x * x + y * y

    /** Angolo del vettore in radianti, misurato dall'asse X in senso antiorario. */
    val angle: Double get() = atan2(y, x)

    /** Normale sinistra: ruotata di +90 gradi. Usata per gli offset delle linee di quota. */
    val leftNormal: Vec2 get() = Vec2(-y, x)

    fun normalized(): Vec2 {
        val len = length
        return if (len < EPSILON) ZERO else Vec2(x / len, y / len)
    }

    fun dot(other: Vec2): Double = x * other.x + y * other.y

    /** Prodotto vettoriale 2D (componente Z): positivo se [other] sta a sinistra di questo. */
    fun cross(other: Vec2): Double = x * other.y - y * other.x

    fun distanceTo(other: Vec2): Double = hypot(other.x - x, other.y - y)

    fun rotate(radians: Double, around: Vec2 = ZERO): Vec2 {
        val c = cos(radians)
        val s = sin(radians)
        val dx = x - around.x
        val dy = y - around.y
        return Vec2(around.x + dx * c - dy * s, around.y + dx * s + dy * c)
    }

    fun isCloseTo(other: Vec2, tolerance: Double = EPSILON): Boolean =
        abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance

    companion object {
        val ZERO = Vec2(0.0, 0.0)

        /**
         * Tolleranza di confronto sulle coordinate modello. I disegni edili arrivano in
         * millimetri: 1e-9 sta ampiamente sotto la precisione utile e sopra il rumore
         * dei double.
         */
        const val EPSILON = 1e-9

        fun polar(origin: Vec2, radians: Double, distance: Double): Vec2 =
            Vec2(origin.x + cos(radians) * distance, origin.y + sin(radians) * distance)
    }
}
