package org.cadviewer.core.model

import org.cadviewer.core.geometry.ArcMath
import org.cadviewer.core.geometry.ArcSegment
import org.cadviewer.core.geometry.Bounds
import org.cadviewer.core.geometry.Vec2
import kotlin.math.cos
import kotlin.math.sin

/** Colore di un'entita' secondo l'AutoCAD Color Index (ACI). */
@JvmInline
value class AciColor(val index: Int) {
    val isByLayer: Boolean get() = index == BY_LAYER
    val isByBlock: Boolean get() = index == BY_BLOCK

    companion object {
        const val BY_BLOCK = 0
        const val BY_LAYER = 256
        val DEFAULT = AciColor(BY_LAYER)
    }
}

/** Entita' geometrica del disegno. Ogni entita' sa dire il proprio ingombro, per il culling. */
sealed interface CadEntity {
    val layer: String
    val color: AciColor
    val bounds: Bounds
}

data class CadLine(
    val start: Vec2,
    val end: Vec2,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    override val bounds: Bounds get() = Bounds.of(start, end)
    val length: Double get() = start.distanceTo(end)
    val midpoint: Vec2 get() = (start + end) / 2.0
}

data class CadPoint(
    val position: Vec2,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    override val bounds: Bounds get() = Bounds.of(position)
}

data class CadCircle(
    val center: Vec2,
    val radius: Double,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    override val bounds: Bounds
        get() = Bounds(center.x - radius, center.y - radius, center.x + radius, center.y + radius)
}

/** Arco antiorario da [startAngleDeg] a [endAngleDeg], come nel DXF. */
data class CadArc(
    val center: Vec2,
    val radius: Double,
    val startAngleDeg: Double,
    val endAngleDeg: Double,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    override val bounds: Bounds get() = ArcMath.arcBounds(center, radius, startAngleDeg, endAngleDeg)
    val startPoint: Vec2 get() = ArcMath.pointOnCircle(center, radius, startAngleDeg)
    val endPoint: Vec2 get() = ArcMath.pointOnCircle(center, radius, endAngleDeg)
    fun asSegment(): ArcSegment = ArcSegment(center, radius, startAngleDeg, endAngleDeg)
}

/** Vertice di polilinea; [bulge] descrive l'eventuale arco fino al vertice successivo. */
data class PolylineVertex(val point: Vec2, val bulge: Double = 0.0)

/** Tratto di polilinea gia' risolto: o un segmento retto, o un arco. */
sealed interface PolylinePiece {
    data class Line(val start: Vec2, val end: Vec2) : PolylinePiece
    data class Arc(val arc: ArcSegment) : PolylinePiece
}

data class CadPolyline(
    val vertices: List<PolylineVertex>,
    val closed: Boolean = false,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {

    /** Tratti della polilinea, con i bulge convertiti in archi veri. */
    fun pieces(): List<PolylinePiece> {
        if (vertices.size < 2) return emptyList()
        val result = mutableListOf<PolylinePiece>()
        val count = if (closed) vertices.size else vertices.size - 1
        for (i in 0 until count) {
            val from = vertices[i]
            val to = vertices[(i + 1) % vertices.size]
            val arc = ArcMath.fromBulge(from.point, to.point, from.bulge)
            result += if (arc != null) PolylinePiece.Arc(arc) else PolylinePiece.Line(from.point, to.point)
        }
        return result
    }

    override val bounds: Bounds
        get() = pieces().fold(Bounds.of(vertices.map { it.point })) { acc, piece ->
            when (piece) {
                is PolylinePiece.Arc -> acc.union(piece.arc.bounds)
                is PolylinePiece.Line -> acc
            }
        }
}

/**
 * Ellisse DXF: [majorAxis] e' l'estremo dell'asse maggiore **relativo** al centro,
 * [axisRatio] il rapporto minore/maggiore, i parametri sono in radianti.
 */
data class CadEllipse(
    val center: Vec2,
    val majorAxis: Vec2,
    val axisRatio: Double,
    val startParam: Double = 0.0,
    val endParam: Double = 2 * Math.PI,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {

    fun pointAt(param: Double): Vec2 {
        val minorAxis = majorAxis.leftNormal * axisRatio
        return center + majorAxis * cos(param) + minorAxis * sin(param)
    }

    fun flatten(steps: Int = 64): List<Vec2> {
        val sweep = endParam - startParam
        return (0..steps).map { i -> pointAt(startParam + sweep * i / steps) }
    }

    override val bounds: Bounds get() = Bounds.of(flatten())
}

enum class TextHorizontalAlign { LEFT, CENTER, RIGHT }

data class CadText(
    val position: Vec2,
    val value: String,
    val height: Double,
    val rotationDeg: Double = 0.0,
    val align: TextHorizontalAlign = TextHorizontalAlign.LEFT,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    override val bounds: Bounds
        get() {
            // Larghezza stimata: senza metriche del font non si puo' fare di meglio prima
            // del rendering, ed e' sufficiente per culling e fit dello zoom.
            val width = value.length * height * ESTIMATED_GLYPH_WIDTH_RATIO
            val corners = listOf(
                Vec2(0.0, 0.0),
                Vec2(width, 0.0),
                Vec2(width, height),
                Vec2(0.0, height),
            ).map { it.rotate(ArcMath.degToRad(rotationDeg)) + position }
            return Bounds.of(corners)
        }

    companion object {
        const val ESTIMATED_GLYPH_WIDTH_RATIO = 0.6
    }
}

/** Faccia piena a 3 o 4 lati (SOLID/3DFACE): usata anche per le punte di freccia delle quote. */
data class CadSolid(
    val points: List<Vec2>,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    override val bounds: Bounds get() = Bounds.of(points)
}

/** Inserimento di un blocco: la geometria vera sta in [CadBlock] e viene risolta al rendering. */
data class CadInsert(
    val blockName: String,
    val position: Vec2,
    val scale: Vec2 = Vec2(1.0, 1.0),
    val rotationDeg: Double = 0.0,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    // L'ingombro reale richiede il blocco: viene calcolato da CadDocument, che ha la tabella.
    override val bounds: Bounds get() = Bounds.of(position)
}

/**
 * Quota gia' presente nel file DXF. Il DXF disegna ogni quota in un blocco anonimo (`*D1`,
 * `*D2`, ...) referenziato dall'entita' DIMENSION: rendendo quel blocco si ottiene esattamente
 * la quota che l'utente vede nel CAD desktop, senza reimplementarne l'aspetto.
 */
data class CadDimensionRef(
    val blockName: String?,
    val insertPoint: Vec2,
    val measurement: Double?,
    val overrideText: String?,
    override val layer: String = DEFAULT_LAYER,
    override val color: AciColor = AciColor.DEFAULT,
) : CadEntity {
    override val bounds: Bounds get() = Bounds.of(insertPoint)
}

const val DEFAULT_LAYER = "0"
