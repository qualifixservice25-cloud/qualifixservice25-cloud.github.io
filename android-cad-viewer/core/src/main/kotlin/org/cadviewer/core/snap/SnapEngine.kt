package org.cadviewer.core.snap

import org.cadviewer.core.geometry.ArcMath
import org.cadviewer.core.geometry.ArcSegment
import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.model.CadArc
import org.cadviewer.core.model.CadCircle
import org.cadviewer.core.model.CadEllipse
import org.cadviewer.core.model.CadEntity
import org.cadviewer.core.model.CadLine
import org.cadviewer.core.model.CadPoint
import org.cadviewer.core.model.CadPolyline
import org.cadviewer.core.model.CadSolid
import org.cadviewer.core.model.CadText
import org.cadviewer.core.model.PolylinePiece
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Tipi di aggancio, in ordine di priorita': a parita' di distanza vince il tipo piu' preciso.
 * L'ordine ricalca quello dei CAD desktop, dove il punto finale batte sempre il "punto piu'
 * vicino" — su touchscreen questa gerarchia e' l'unica cosa che rende quotabile un disegno
 * con un dito largo tre millimetri.
 */
enum class SnapType(val priority: Int, val label: String) {
    ENDPOINT(0, "Fine"),
    INTERSECTION(1, "Intersezione"),
    MIDPOINT(2, "Medio"),
    CENTER(3, "Centro"),
    QUADRANT(4, "Quadrante"),
    PERPENDICULAR(5, "Perpendicolare"),
    NEAREST(6, "Vicino"),
    ;

    companion object {
        /** Set attivo di default: tutto tranne il "vicino", che altrimenti vince sempre. */
        val DEFAULTS: Set<SnapType> = setOf(ENDPOINT, INTERSECTION, MIDPOINT, CENTER, QUADRANT, PERPENDICULAR)

        val ALL: Set<SnapType> = entries.toSet()
    }
}

data class SnapResult(
    val point: Vec2,
    val type: SnapType,
    val distance: Double,
    val entity: CadEntity?,
)

/**
 * Motore di aggancio. Lavora in coordinate modello: chi chiama converte il raggio di ricerca
 * dai pixel del dito alle unita' del disegno, cosi' la tolleranza resta costante sullo schermo
 * a qualsiasi zoom.
 */
class SnapEngine(entities: List<CadEntity>) {

    private val entities: List<CadEntity> = entities.filter { it !is CadText }

    fun snap(
        query: Vec2,
        radius: Double,
        types: Set<SnapType> = SnapType.DEFAULTS,
        from: Vec2? = null,
    ): SnapResult? {
        if (radius <= 0.0) return null
        val nearby = entities.filter { it.bounds.inflate(radius).contains(query) }
        if (nearby.isEmpty()) return null

        val candidates = mutableListOf<SnapResult>()

        for (entity in nearby) {
            for ((point, type) in candidatePoints(entity, query, from, types)) {
                if (type !in types) continue
                val distance = point.distanceTo(query)
                if (distance <= radius) candidates += SnapResult(point, type, distance, entity)
            }
        }

        if (SnapType.INTERSECTION in types) {
            candidates += intersectionCandidates(nearby, query, radius)
        }

        return candidates.minWithOrNull(
            compareBy<SnapResult> { it.type.priority }.thenBy { it.distance },
        )
    }

    private fun candidatePoints(
        entity: CadEntity,
        query: Vec2,
        from: Vec2?,
        types: Set<SnapType>,
    ): List<Pair<Vec2, SnapType>> {
        val result = mutableListOf<Pair<Vec2, SnapType>>()

        when (entity) {
            is CadPoint -> result += entity.position to SnapType.ENDPOINT

            is CadLine -> {
                result += entity.start to SnapType.ENDPOINT
                result += entity.end to SnapType.ENDPOINT
                result += entity.midpoint to SnapType.MIDPOINT
                result += nearestOnSegment(query, entity.start, entity.end) to SnapType.NEAREST
                if (from != null && SnapType.PERPENDICULAR in types) {
                    perpendicularFoot(from, entity.start, entity.end)?.let {
                        result += it to SnapType.PERPENDICULAR
                    }
                }
            }

            is CadCircle -> {
                result += entity.center to SnapType.CENTER
                result += quadrants(entity.center, entity.radius).map { it to SnapType.QUADRANT }
                result += nearestOnCircle(query, entity.center, entity.radius) to SnapType.NEAREST
            }

            is CadArc -> result += arcCandidates(entity.asSegment(), query)

            is CadPolyline -> {
                for (piece in entity.pieces()) {
                    when (piece) {
                        is PolylinePiece.Line -> {
                            result += piece.start to SnapType.ENDPOINT
                            result += piece.end to SnapType.ENDPOINT
                            result += (piece.start + piece.end) / 2.0 to SnapType.MIDPOINT
                            result += nearestOnSegment(query, piece.start, piece.end) to SnapType.NEAREST
                            if (from != null && SnapType.PERPENDICULAR in types) {
                                perpendicularFoot(from, piece.start, piece.end)?.let {
                                    result += it to SnapType.PERPENDICULAR
                                }
                            }
                        }

                        is PolylinePiece.Arc -> result += arcCandidates(piece.arc, query)
                    }
                }
            }

            is CadEllipse -> {
                result += entity.center to SnapType.CENTER
                val flattened = entity.flatten()
                result += flattened.first() to SnapType.ENDPOINT
                result += flattened.last() to SnapType.ENDPOINT
                result += flattened.minBy { it.distanceTo(query) } to SnapType.NEAREST
            }

            is CadSolid -> {
                val points = entity.points
                result += points.map { it to SnapType.ENDPOINT }
                for (i in points.indices) {
                    val a = points[i]
                    val b = points[(i + 1) % points.size]
                    result += (a + b) / 2.0 to SnapType.MIDPOINT
                    result += nearestOnSegment(query, a, b) to SnapType.NEAREST
                }
            }

            else -> Unit
        }
        return result
    }

    private fun arcCandidates(arc: ArcSegment, query: Vec2): List<Pair<Vec2, SnapType>> {
        val result = mutableListOf<Pair<Vec2, SnapType>>()
        result += arc.startPoint to SnapType.ENDPOINT
        result += arc.endPoint to SnapType.ENDPOINT
        result += arc.center to SnapType.CENTER
        result += ArcMath.pointOnCircle(
            arc.center,
            arc.radius,
            arc.startDeg + arc.sweepDeg / 2.0,
        ) to SnapType.MIDPOINT
        // Solo i quadranti effettivamente percorsi dall'arco: gli altri non esistono sul disegno.
        result += quadrants(arc.center, arc.radius)
            .filter { point ->
                ArcMath.containsAngle(arc.startDeg, arc.endDeg, ArcMath.radToDeg((point - arc.center).angle))
            }
            .map { it to SnapType.QUADRANT }
        nearestOnArc(query, arc)?.let { result += it to SnapType.NEAREST }
        return result
    }

    /**
     * Intersezioni fra le entita' vicine al tocco. Il costo quadratico e' accettabile perche'
     * il set e' gia' filtrato al raggio di ricerca: sono le poche entita' sotto il dito.
     */
    private fun intersectionCandidates(
        nearby: List<CadEntity>,
        query: Vec2,
        radius: Double,
    ): List<SnapResult> {
        val segments = nearby.flatMap { entity -> segmentsOf(entity).map { entity to it } }
        val circles = nearby.flatMap { entity -> circlesOf(entity).map { entity to it } }
        val result = mutableListOf<SnapResult>()

        for (i in segments.indices) {
            for (j in i + 1 until segments.size) {
                val (entityA, a) = segments[i]
                val (_, b) = segments[j]
                segmentIntersection(a.first, a.second, b.first, b.second)?.let { point ->
                    val distance = point.distanceTo(query)
                    if (distance <= radius) {
                        result += SnapResult(point, SnapType.INTERSECTION, distance, entityA)
                    }
                }
            }
        }

        for ((entity, segment) in segments) {
            for ((_, circle) in circles) {
                for (point in segmentCircleIntersections(segment.first, segment.second, circle)) {
                    val distance = point.distanceTo(query)
                    if (distance <= radius) {
                        result += SnapResult(point, SnapType.INTERSECTION, distance, entity)
                    }
                }
            }
        }
        return result
    }

    private fun segmentsOf(entity: CadEntity): List<Pair<Vec2, Vec2>> = when (entity) {
        is CadLine -> listOf(entity.start to entity.end)
        is CadPolyline -> entity.pieces().filterIsInstance<PolylinePiece.Line>().map { it.start to it.end }
        is CadSolid -> entity.points.indices.map { i ->
            entity.points[i] to entity.points[(i + 1) % entity.points.size]
        }

        else -> emptyList()
    }

    private fun circlesOf(entity: CadEntity): List<ArcSegment> = when (entity) {
        is CadCircle -> listOf(ArcSegment(entity.center, entity.radius, 0.0, 360.0))
        is CadArc -> listOf(entity.asSegment())
        is CadPolyline -> entity.pieces().filterIsInstance<PolylinePiece.Arc>().map { it.arc }
        else -> emptyList()
    }

    companion object {

        fun quadrants(center: Vec2, radius: Double): List<Vec2> =
            listOf(0.0, 90.0, 180.0, 270.0).map { ArcMath.pointOnCircle(center, radius, it) }

        fun nearestOnSegment(query: Vec2, a: Vec2, b: Vec2): Vec2 {
            val ab = b - a
            val lengthSquared = ab.lengthSquared
            if (lengthSquared < Vec2.EPSILON) return a
            val t = ((query - a).dot(ab) / lengthSquared).coerceIn(0.0, 1.0)
            return a + ab * t
        }

        fun nearestOnCircle(query: Vec2, center: Vec2, radius: Double): Vec2 {
            val direction = query - center
            if (direction.length < Vec2.EPSILON) return Vec2(center.x + radius, center.y)
            return center + direction.normalized() * radius
        }

        /** Punto piu' vicino sull'arco, null se la proiezione cade fuori dal settore. */
        fun nearestOnArc(query: Vec2, arc: ArcSegment): Vec2? {
            val angle = ArcMath.radToDeg((query - arc.center).angle)
            if (!ArcMath.containsAngle(arc.startDeg, arc.endDeg, angle)) return null
            return ArcMath.pointOnCircle(arc.center, arc.radius, angle)
        }

        /** Piede della perpendicolare condotta da [from]; null se cade fuori dal segmento. */
        fun perpendicularFoot(from: Vec2, a: Vec2, b: Vec2): Vec2? {
            val ab = b - a
            val lengthSquared = ab.lengthSquared
            if (lengthSquared < Vec2.EPSILON) return null
            val t = (from - a).dot(ab) / lengthSquared
            if (t < 0.0 || t > 1.0) return null
            return a + ab * t
        }

        /** Intersezione fra due segmenti; null se paralleli o se il punto cade fuori. */
        fun segmentIntersection(a1: Vec2, a2: Vec2, b1: Vec2, b2: Vec2): Vec2? {
            val r = a2 - a1
            val s = b2 - b1
            val denominator = r.cross(s)
            if (abs(denominator) < 1e-12) return null
            val t = (b1 - a1).cross(s) / denominator
            val u = (b1 - a1).cross(r) / denominator
            if (t < 0.0 || t > 1.0 || u < 0.0 || u > 1.0) return null
            return a1 + r * t
        }

        /** Intersezioni fra un segmento e un arco/cerchio, limitate al settore dell'arco. */
        fun segmentCircleIntersections(a: Vec2, b: Vec2, arc: ArcSegment): List<Vec2> {
            val d = b - a
            val f = a - arc.center
            val qa = d.lengthSquared
            if (qa < Vec2.EPSILON) return emptyList()
            val qb = 2 * f.dot(d)
            val qc = f.lengthSquared - arc.radius * arc.radius
            val discriminant = qb * qb - 4 * qa * qc
            if (discriminant < 0) return emptyList()

            val root = sqrt(discriminant)
            return listOf((-qb - root) / (2 * qa), (-qb + root) / (2 * qa))
                .filter { it in 0.0..1.0 }
                .map { a + d * it }
                .filter { point ->
                    ArcMath.containsAngle(
                        arc.startDeg,
                        arc.endDeg,
                        ArcMath.radToDeg((point - arc.center).angle),
                    )
                }
        }
    }
}
