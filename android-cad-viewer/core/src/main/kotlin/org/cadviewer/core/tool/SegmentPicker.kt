package org.cadviewer.core.tool

import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.model.CadEntity
import org.cadviewer.core.model.CadLine
import org.cadviewer.core.model.CadPolyline
import org.cadviewer.core.model.CadSolid
import org.cadviewer.core.model.PolylinePiece
import org.cadviewer.core.snap.SnapEngine
import kotlin.math.abs

/** Segmento retto del disegno, individuato sotto il dito. */
data class PickedSegment(val start: Vec2, val end: Vec2) {
    val length: Double get() = start.distanceTo(end)
    val midpoint: Vec2 get() = (start + end) / 2.0

    /** Versore da [start] verso [end]; vettore nullo se il segmento e' degenere. */
    val direction: Vec2 get() = (end - start).normalized()
}

/**
 * Individua il segmento toccato e misura la distanza fra due segmenti.
 *
 * E' il modo piu' rapido di leggere un disegno in cantiere: si tocca un muro e si legge quanto
 * e' lungo, si tocca quello di fronte e si legge la luce fra i due, senza dover agganciare
 * quattro spigoli a uno a uno.
 */
object SegmentPicker {

    /**
     * Segmento piu' vicino a [near] entro [tolerance]. Considera le linee, i tratti retti
     * delle polilinee (con cui sono disegnati quasi tutti i muri) e i lati delle facce piene.
     */
    fun nearest(
        entities: List<CadEntity>,
        near: Vec2,
        tolerance: Double = Double.MAX_VALUE,
    ): PickedSegment? {
        var best: PickedSegment? = null
        var bestDistance = Double.MAX_VALUE

        fun consider(start: Vec2, end: Vec2) {
            if (start.distanceTo(end) < Vec2.EPSILON) return
            val distance = near.distanceTo(SnapEngine.nearestOnSegment(near, start, end))
            if (distance < bestDistance && distance <= tolerance) {
                bestDistance = distance
                best = PickedSegment(start, end)
            }
        }

        for (entity in entities) {
            when (entity) {
                is CadLine -> consider(entity.start, entity.end)

                is CadPolyline -> entity.pieces()
                    .filterIsInstance<PolylinePiece.Line>()
                    .forEach { consider(it.start, it.end) }

                is CadSolid -> {
                    val points = entity.points
                    for (i in points.indices) consider(points[i], points[(i + 1) % points.size])
                }

                else -> Unit
            }
        }
        return best
    }

    /**
     * Coppia di punti fra cui misurare la distanza dei due segmenti: il primo sta su [a],
     * il secondo su [b].
     *
     * I due casi vanno distinti perche' rispondono a due domande diverse. Fra segmenti
     * paralleli — due muri affacciati — la risposta utile e' la distanza in perpendicolare,
     * presa a meta' del tratto in cui si guardano: e' la luce del vano. Fra segmenti obliqui
     * non esiste una distanza sola, e l'unica che significhi qualcosa e' la minima, che in
     * due dimensioni cade sempre su un estremo di uno dei due.
     */
    fun closestPoints(a: PickedSegment, b: PickedSegment): Pair<Vec2, Vec2> {
        SnapEngine.segmentIntersection(a.start, a.end, b.start, b.end)?.let { return it to it }
        return perpendicularPoints(a, b) ?: nearestEndpointPair(a, b)
    }

    /**
     * Punti in perpendicolare fra due segmenti paralleli, presi a meta' della loro
     * sovrapposizione. Null se non sono paralleli o se non si sovrappongono affatto: due muri
     * sfalsati che non si guardano non hanno una luce da misurare.
     */
    private fun perpendicularPoints(a: PickedSegment, b: PickedSegment): Pair<Vec2, Vec2>? {
        val u = a.direction
        val v = b.direction
        if (u.length < 0.5 || v.length < 0.5) return null
        if (abs(u.cross(v)) > PARALLEL_SINE_TOLERANCE) return null

        // Estremi di b proiettati sull'asse di a, intersecati con l'estensione di a.
        val first = (b.start - a.start).dot(u)
        val second = (b.end - a.start).dot(u)
        val overlapStart = maxOf(0.0, minOf(first, second))
        val overlapEnd = minOf(a.length, maxOf(first, second))
        if (overlapEnd < overlapStart) return null

        val onA = a.start + u * ((overlapStart + overlapEnd) / 2.0)
        return onA to SnapEngine.nearestOnSegment(onA, b.start, b.end)
    }

    private fun nearestEndpointPair(a: PickedSegment, b: PickedSegment): Pair<Vec2, Vec2> = listOf(
        a.start to SnapEngine.nearestOnSegment(a.start, b.start, b.end),
        a.end to SnapEngine.nearestOnSegment(a.end, b.start, b.end),
        SnapEngine.nearestOnSegment(b.start, a.start, a.end) to b.start,
        SnapEngine.nearestOnSegment(b.end, a.start, a.end) to b.end,
    ).minBy { (onA, onB) -> onA.distanceTo(onB) }

    /**
     * Seno dell'angolo entro cui due segmenti si considerano paralleli: un grado. I disegni
     * rilevati sul posto non hanno muri paralleli al millesimo di grado, e trattarli come
     * obliqui darebbe la distanza fra due spigoli invece della luce fra i due muri.
     */
    private const val PARALLEL_SINE_TOLERANCE = 0.0175
}
