package org.qualifix.cad.core.tool

import org.qualifix.cad.core.dimension.AngularDimension
import org.qualifix.cad.core.dimension.Dimension
import org.qualifix.cad.core.dimension.DimensionStyle
import org.qualifix.cad.core.dimension.LinearDimension
import org.qualifix.cad.core.dimension.LinearOrientation
import org.qualifix.cad.core.dimension.OrdinateAxis
import org.qualifix.cad.core.dimension.OrdinateDimension
import org.qualifix.cad.core.dimension.RadialDimension
import org.qualifix.cad.core.geometry.ArcMath
import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.model.CadArc
import org.qualifix.cad.core.model.CadCircle
import org.qualifix.cad.core.model.CadEntity
import org.qualifix.cad.core.model.CadPolyline
import org.qualifix.cad.core.model.PolylinePiece
import kotlin.math.abs

/**
 * Strumenti selezionabili nella barra. [requiredPoints] e' quanti tocchi servono per
 * completare la quota: e' il dato che guida i suggerimenti a schermo ("tocca il secondo
 * punto", "scegli dove mettere la linea di quota").
 */
enum class CadTool(val requiredPoints: Int) {
    /** Nessuno strumento: un dito sposta il disegno. */
    PAN(0),

    /** Misura al volo fra due punti, senza lasciare una quota sul disegno. */
    MEASURE(2),

    LINEAR(3),
    ALIGNED(3),
    ANGULAR(4),
    RADIUS(2),
    DIAMETER(2),
    ORDINATE(3),
    ;

    val isDimensionTool: Boolean get() = this != PAN && this != MEASURE
    val needsPicking: Boolean get() = requiredPoints > 0
}

/** Cerchio o arco individuato sotto il dito, con centro e raggio da quotare. */
data class CircularTarget(val center: Vec2, val radius: Double)

/**
 * Costruisce la quota a partire dai punti toccati dall'utente.
 *
 * Sta nel core, e non nell'interfaccia, per un motivo pratico: e' logica che decide *cosa
 * viene misurato*, quindi va verificata con dei test e non provata a mano sul telefono.
 */
object DimensionBuilder {

    fun build(
        tool: CadTool,
        points: List<Vec2>,
        style: DimensionStyle = DimensionStyle(),
        entities: List<CadEntity> = emptyList(),
        circularTolerance: Double = Double.MAX_VALUE,
    ): Dimension? {
        if (points.size < tool.requiredPoints) return null

        return when (tool) {
            CadTool.PAN -> null

            // La misura rapida e' una quota allineata appoggiata sul segmento misurato:
            // stessa matematica, ma non viene salvata sul disegno.
            CadTool.MEASURE -> LinearDimension(
                first = points[0],
                second = points[1],
                dimLinePoint = (points[0] + points[1]) / 2.0,
                orientation = LinearOrientation.ALIGNED,
                style = style,
            )

            CadTool.LINEAR -> LinearDimension(
                first = points[0],
                second = points[1],
                dimLinePoint = points[2],
                // Fra quota orizzontale e verticale decide il verso in cui l'utente ha
                // trascinato la linea di quota, come nel comando DIMLINEAR del CAD.
                orientation = dominantOrientation(points[0], points[1], points[2]),
                style = style,
            )

            CadTool.ALIGNED -> LinearDimension(
                first = points[0],
                second = points[1],
                dimLinePoint = points[2],
                orientation = LinearOrientation.ALIGNED,
                style = style,
            )

            CadTool.ANGULAR -> AngularDimension(
                vertex = points[0],
                first = points[1],
                second = points[2],
                arcPoint = points[3],
                style = style,
            )

            CadTool.RADIUS, CadTool.DIAMETER -> {
                val target = findCircular(entities, points[0], circularTolerance) ?: return null
                RadialDimension(
                    center = target.center,
                    radius = target.radius,
                    angleDeg = ArcMath.radToDeg((points[1] - target.center).angle),
                    diameter = tool == CadTool.DIAMETER,
                    style = style,
                )
            }

            CadTool.ORDINATE -> OrdinateDimension(
                origin = points[0],
                feature = points[1],
                leaderEnd = points[2],
                // Richiamo tirato in verticale: si quota la posizione lungo X. In orizzontale,
                // lungo Y. E' la stessa convenzione del comando DIMORDINATE.
                axis = if (abs(points[2].y - points[1].y) >= abs(points[2].x - points[1].x)) {
                    OrdinateAxis.X
                } else {
                    OrdinateAxis.Y
                },
                style = style,
            )
        }
    }

    /**
     * Orientamento di una quota lineare in base a dove e' stata trascinata la linea di quota:
     * spostandola sopra o sotto si quota la distanza orizzontale, di lato quella verticale.
     */
    fun dominantOrientation(first: Vec2, second: Vec2, dimLinePoint: Vec2): LinearOrientation {
        val midpoint = (first + second) / 2.0
        val offset = dimLinePoint - midpoint
        return if (abs(offset.y) >= abs(offset.x)) {
            LinearOrientation.HORIZONTAL
        } else {
            LinearOrientation.VERTICAL
        }
    }

    /**
     * Cerchio o arco piu' vicino al punto toccato. Considera anche gli archi interni alle
     * polilinee, che nei disegni edili sono la forma tipica degli arrotondamenti e delle
     * ante di porta.
     */
    fun findCircular(
        entities: List<CadEntity>,
        near: Vec2,
        tolerance: Double = Double.MAX_VALUE,
    ): CircularTarget? {
        var best: CircularTarget? = null
        var bestDistance = Double.MAX_VALUE

        fun consider(center: Vec2, radius: Double) {
            if (radius <= 0.0) return
            val toCenter = near.distanceTo(center)
            // Vale sia toccare la circonferenza sia toccare il centro: sul disegno il centro
            // e' spesso l'unico punto agganciabile di un cerchio piccolo.
            val distance = minOf(abs(toCenter - radius), toCenter)
            if (distance < bestDistance && distance <= tolerance) {
                bestDistance = distance
                best = CircularTarget(center, radius)
            }
        }

        for (entity in entities) {
            when (entity) {
                is CadCircle -> consider(entity.center, entity.radius)
                is CadArc -> consider(entity.center, entity.radius)
                is CadPolyline -> entity.pieces()
                    .filterIsInstance<PolylinePiece.Arc>()
                    .forEach { consider(it.arc.center, it.arc.radius) }

                else -> Unit
            }
        }
        return best
    }
}
