package org.cadviewer.core.geometry

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * Trasformazione affine 2D, nella forma:
 * ```
 * x' = a*x + c*y + tx
 * y' = b*x + d*y + ty
 * ```
 * Serve a risolvere gli inserimenti di blocco (scala, rotazione, traslazione) e puo' comporre
 * catene di blocchi annidati.
 */
data class Transform2D(
    val a: Double = 1.0,
    val b: Double = 0.0,
    val c: Double = 0.0,
    val d: Double = 1.0,
    val tx: Double = 0.0,
    val ty: Double = 0.0,
) {
    fun apply(point: Vec2): Vec2 =
        Vec2(a * point.x + c * point.y + tx, b * point.x + d * point.y + ty)

    /** Applica solo la parte lineare: per direzioni e vettori, non per posizioni. */
    fun applyDirection(vector: Vec2): Vec2 =
        Vec2(a * vector.x + c * vector.y, b * vector.x + d * vector.y)

    /** `this` applicata dopo [other]. */
    fun compose(other: Transform2D): Transform2D = Transform2D(
        a = a * other.a + c * other.b,
        b = b * other.a + d * other.b,
        c = a * other.c + c * other.d,
        d = b * other.c + d * other.d,
        tx = a * other.tx + c * other.ty + tx,
        ty = b * other.tx + d * other.ty + ty,
    )

    /** Fattore di scala medio: usato per raggi e altezze del testo. */
    val averageScale: Double
        get() = (hypot(a, b) + hypot(c, d)) / 2.0

    val isUniformScale: Boolean
        get() = abs(hypot(a, b) - hypot(c, d)) < 1e-9

    /** Rotazione introdotta dalla trasformazione, in gradi. */
    val rotationDeg: Double
        get() = ArcMath.radToDeg(Vec2(a, b).angle)

    /** True se la trasformazione ribalta l'orientamento (scala negativa su un solo asse). */
    val isMirrored: Boolean
        get() = (a * d - b * c) < 0

    companion object {
        val IDENTITY = Transform2D()

        fun translation(offset: Vec2) = Transform2D(tx = offset.x, ty = offset.y)

        fun scaling(scale: Vec2) = Transform2D(a = scale.x, d = scale.y)

        fun rotation(degrees: Double): Transform2D {
            val r = ArcMath.degToRad(degrees)
            return Transform2D(a = cos(r), b = sin(r), c = -sin(r), d = cos(r))
        }

        /** Trasformazione di un INSERT: scala, poi rotazione, poi traslazione. */
        fun insert(position: Vec2, scale: Vec2, rotationDeg: Double): Transform2D =
            translation(position).compose(rotation(rotationDeg)).compose(scaling(scale))
    }
}
