package org.qualifix.cad.core.geometry

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan

/**
 * Matematica degli archi secondo le convenzioni DXF: gli angoli sono in gradi, misurati
 * dall'asse X positivo, e un arco va **sempre** in senso antiorario dall'angolo iniziale a
 * quello finale.
 */
object ArcMath {

    fun degToRad(degrees: Double): Double = degrees * PI / 180.0

    fun radToDeg(radians: Double): Double = radians * 180.0 / PI

    /** Riporta un angolo in gradi nell'intervallo [0, 360). */
    fun normalizeDeg(degrees: Double): Double {
        var a = degrees % 360.0
        if (a < 0) a += 360.0
        return a
    }

    /** Ampiezza in gradi dell'arco antiorario da [startDeg] a [endDeg]; 360 per il cerchio pieno. */
    fun sweepDeg(startDeg: Double, endDeg: Double): Double {
        val sweep = normalizeDeg(endDeg - startDeg)
        return if (sweep <= Vec2.EPSILON) 360.0 else sweep
    }

    fun containsAngle(startDeg: Double, endDeg: Double, angleDeg: Double): Boolean {
        val sweep = sweepDeg(startDeg, endDeg)
        val delta = normalizeDeg(angleDeg - startDeg)
        return delta <= sweep + 1e-9
    }

    fun pointOnCircle(center: Vec2, radius: Double, angleDeg: Double): Vec2 {
        val a = degToRad(angleDeg)
        return Vec2(center.x + radius * cos(a), center.y + radius * sin(a))
    }

    /**
     * Ingombro esatto di un arco: oltre agli estremi conta solo i quadranti (0/90/180/270)
     * effettivamente attraversati. Usare l'ingombro del cerchio intero gonfierebbe il fit
     * dello zoom su disegni pieni di archi corti.
     */
    fun arcBounds(center: Vec2, radius: Double, startDeg: Double, endDeg: Double): Bounds {
        var bounds = Bounds.of(
            pointOnCircle(center, radius, startDeg),
            pointOnCircle(center, radius, endDeg),
        )
        for (quadrant in listOf(0.0, 90.0, 180.0, 270.0)) {
            if (containsAngle(startDeg, endDeg, quadrant)) {
                bounds = bounds.include(pointOnCircle(center, radius, quadrant))
            }
        }
        return bounds
    }

    /** Discretizza un arco in punti, con passo scelto in base a [maxSegmentDeg]. */
    fun flattenArc(
        center: Vec2,
        radius: Double,
        startDeg: Double,
        endDeg: Double,
        maxSegmentDeg: Double = 6.0,
    ): List<Vec2> {
        val sweep = sweepDeg(startDeg, endDeg)
        val steps = maxOf(2, ceil(sweep / maxSegmentDeg).toInt())
        return (0..steps).map { i ->
            pointOnCircle(center, radius, startDeg + sweep * i / steps)
        }
    }

    /**
     * Arco descritto da un bulge di polilinea. Nel DXF il bulge di un segmento e' la tangente
     * di un quarto dell'angolo al centro, negativo se l'arco procede in senso orario
     * (bulge 1 = semicerchio). Restituisce null per i segmenti rettilinei.
     */
    fun fromBulge(start: Vec2, end: Vec2, bulge: Double): ArcSegment? {
        if (abs(bulge) < 1e-12) return null
        val chord = end - start
        val chordLength = chord.length
        if (chordLength < Vec2.EPSILON) return null

        val includedAngle = 4.0 * atan(bulge)
        val radius = chordLength / (2.0 * sin(includedAngle / 2.0))
        val midpoint = (start + end) / 2.0
        // Distanza con segno dal punto medio della corda al centro, lungo la normale sinistra.
        val centerOffset = chordLength / 2.0 / tan(includedAngle / 2.0)
        val center = midpoint + chord.leftNormal.normalized() * centerOffset

        val startAngle = radToDeg((start - center).angle)
        val endAngle = radToDeg((end - center).angle)
        // Il modello tiene gli archi sempre antiorari: con bulge negativo si scambiano gli estremi.
        return if (bulge > 0) {
            ArcSegment(center, abs(radius), normalizeDeg(startAngle), normalizeDeg(endAngle))
        } else {
            ArcSegment(center, abs(radius), normalizeDeg(endAngle), normalizeDeg(startAngle))
        }
    }
}

/** Arco antiorario da [startDeg] a [endDeg]. */
data class ArcSegment(
    val center: Vec2,
    val radius: Double,
    val startDeg: Double,
    val endDeg: Double,
) {
    val startPoint: Vec2 get() = ArcMath.pointOnCircle(center, radius, startDeg)
    val endPoint: Vec2 get() = ArcMath.pointOnCircle(center, radius, endDeg)
    val sweepDeg: Double get() = ArcMath.sweepDeg(startDeg, endDeg)
    val length: Double get() = radius * ArcMath.degToRad(sweepDeg)
    val bounds: Bounds get() = ArcMath.arcBounds(center, radius, startDeg, endDeg)
}
