package org.qualifix.cad.core.dimension

import org.qualifix.cad.core.geometry.ArcMath
import org.qualifix.cad.core.geometry.ArcSegment
import org.qualifix.cad.core.geometry.Bounds
import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.measure.MeasurementFormatter
import kotlin.math.abs

/** Orientamento di una quota lineare. */
enum class LinearOrientation {
    /** Misura la sola componente orizzontale (quota lineare classica). */
    HORIZONTAL,

    /** Misura la sola componente verticale. */
    VERTICAL,

    /** Misura la distanza reale fra i due punti, parallela al segmento. */
    ALIGNED,
}

/** Asse di riferimento di una quota ordinata. */
enum class OrdinateAxis { X, Y }

/**
 * Una quota creata dall'utente.
 *
 * Ogni quota conosce due cose: quanto misura ([measure]) e come si disegna ([geometry]).
 * Sono separate di proposito: la misura e' il dato su cui l'utente prende decisioni in
 * cantiere ed e' verificabile con un test, la geometria e' solo la sua rappresentazione.
 */
sealed interface Dimension {
    val style: DimensionStyle
    val id: String

    /** Valore misurato in unita' del disegno (gradi per le quote angolari). */
    fun measure(): Double

    fun geometry(formatter: MeasurementFormatter): DimensionGeometry

    fun text(formatter: MeasurementFormatter): String

    fun bounds(formatter: MeasurementFormatter): Bounds = geometry(formatter).bounds
}

/**
 * Quota lineare fra due punti. [dimLinePoint] e' il punto per cui passa la linea di quota:
 * e' il terzo tocco dell'utente, quello che decide a che distanza dall'oggetto si stacca la quota.
 */
data class LinearDimension(
    val first: Vec2,
    val second: Vec2,
    val dimLinePoint: Vec2,
    val orientation: LinearOrientation = LinearOrientation.ALIGNED,
    override val style: DimensionStyle = DimensionStyle(),
    override val id: String = newDimensionId(),
) : Dimension {

    /** Versore lungo cui si misura. */
    val direction: Vec2
        get() = when (orientation) {
            LinearOrientation.HORIZONTAL -> Vec2(1.0, 0.0)
            LinearOrientation.VERTICAL -> Vec2(0.0, 1.0)
            LinearOrientation.ALIGNED -> (second - first).normalized().takeIf { it.length > 0.5 }
                ?: Vec2(1.0, 0.0)
        }

    override fun measure(): Double = abs((second - first).dot(direction))

    override fun text(formatter: MeasurementFormatter): String =
        style.overrideText ?: formatter
            .withPrecision(linear = style.precision)
            .formatLinear(measure(), tolerance = style.tolerance)

    override fun geometry(formatter: MeasurementFormatter): DimensionGeometry {
        val u = direction
        val n = u.leftNormal
        // Proiezione dei due punti sulla retta di quota, che passa per dimLinePoint.
        fun project(p: Vec2): Vec2 = p + n * (dimLinePoint - p).dot(n)

        val d1 = project(first)
        val d2 = project(second)

        val segments = mutableListOf(DimSegment(d1, d2))
        segments += extensionLine(first, d1)
        segments += extensionLine(second, d2)

        // Le frecce puntano verso l'esterno, cioe' ognuna verso il proprio estremo.
        val alongLine = (d2 - d1).normalized()
        val arrows = if (alongLine.length > 0.5) {
            listOf(arrowhead(d1, -alongLine), arrowhead(d2, alongLine))
        } else {
            emptyList()
        }

        val midpoint = (d1 + d2) / 2.0
        // Il testo va sul lato opposto all'oggetto misurato: e' il lato da cui la quota
        // e' stata staccata, quindi non copre mai la geometria che sta quotando.
        val awayFromObject = (d1 - first).normalized().takeIf { it.length > 0.5 } ?: n
        val textPosition = midpoint + awayFromObject * (style.effectiveTextGap + style.effectiveTextHeight / 2)

        return DimensionGeometry(
            segments = segments,
            arrows = arrows,
            text = DimensionText(
                value = text(formatter),
                position = textPosition,
                height = style.effectiveTextHeight,
                rotationDeg = readableAngle(ArcMath.radToDeg(u.angle)),
            ),
        )
    }

    private fun extensionLine(from: Vec2, to: Vec2): List<DimSegment> {
        val direction = (to - from).normalized()
        if (direction.length < 0.5) return emptyList()
        val start = from + direction * style.effectiveExtensionOffset
        val end = to + direction * style.effectiveExtensionOvershoot
        // Con un offset piu' lungo della distanza fra punto e linea di quota la linea di
        // estensione si rovescerebbe: in quel caso non si disegna.
        if ((end - start).dot(direction) <= 0) return emptyList()
        return listOf(DimSegment(start, end))
    }

    private fun arrowhead(tip: Vec2, outward: Vec2): Arrowhead = buildArrowhead(tip, outward, style)
}

/**
 * Quota angolare fra due semirette uscenti da [vertex]. L'arco passa per [arcPoint]: e' il
 * tocco con cui l'utente sceglie sia il raggio sia **quale** dei due angoli quotare, esattamente
 * come nel CAD desktop.
 */
data class AngularDimension(
    val vertex: Vec2,
    val first: Vec2,
    val second: Vec2,
    val arcPoint: Vec2,
    override val style: DimensionStyle = DimensionStyle(),
    override val id: String = newDimensionId(),
) : Dimension {

    private val startAngleDeg: Double get() = ArcMath.radToDeg((first - vertex).angle)
    private val endAngleDeg: Double get() = ArcMath.radToDeg((second - vertex).angle)
    val radius: Double get() = vertex.distanceTo(arcPoint)

    /** Arco effettivamente quotato: quello dalla parte in cui l'utente ha messo il punto. */
    fun arc(): ArcSegment {
        val a1 = ArcMath.normalizeDeg(startAngleDeg)
        val a2 = ArcMath.normalizeDeg(endAngleDeg)
        val pickAngle = ArcMath.normalizeDeg(ArcMath.radToDeg((arcPoint - vertex).angle))
        return if (ArcMath.containsAngle(a1, a2, pickAngle)) {
            ArcSegment(vertex, radius, a1, a2)
        } else {
            ArcSegment(vertex, radius, a2, a1)
        }
    }

    override fun measure(): Double = arc().sweepDeg

    override fun text(formatter: MeasurementFormatter): String =
        style.overrideText ?: formatter
            .withPrecision(angular = style.angularPrecision)
            .formatAngle(measure())

    override fun geometry(formatter: MeasurementFormatter): DimensionGeometry {
        val arc = arc()
        val segments = mutableListOf<DimSegment>()

        // Linee di estensione: prolungano i due lati fino all'arco, se l'arco li supera.
        for (point in listOf(first, second)) {
            val distance = vertex.distanceTo(point)
            if (distance < Vec2.EPSILON) continue
            val direction = (point - vertex).normalized()
            if (radius > distance) {
                segments += DimSegment(
                    point + direction * style.effectiveExtensionOffset,
                    vertex + direction * (radius + style.effectiveExtensionOvershoot),
                )
            }
        }

        // Frecce tangenti all'arco, una per estremo, rivolte nel verso di percorrenza.
        val startTangent = (arc.startPoint - vertex).normalized().leftNormal
        val endTangent = (arc.endPoint - vertex).normalized().leftNormal
        val arrows = listOf(
            buildArrowhead(arc.startPoint, -startTangent, style),
            buildArrowhead(arc.endPoint, endTangent, style),
        )

        val midAngle = arc.startDeg + arc.sweepDeg / 2.0
        val textPosition = ArcMath.pointOnCircle(
            vertex,
            radius + style.effectiveTextGap + style.effectiveTextHeight / 2,
            midAngle,
        )

        return DimensionGeometry(
            segments = segments,
            arrows = arrows,
            arcs = listOf(arc),
            text = DimensionText(
                value = text(formatter),
                position = textPosition,
                height = style.effectiveTextHeight,
                rotationDeg = readableAngle(midAngle + 90.0),
            ),
        )
    }
}

/**
 * Quota radiale o diametrale su un cerchio o un arco. [angleDeg] e' la direzione della
 * linea di richiamo, cioe' dove l'utente ha toccato la circonferenza.
 */
data class RadialDimension(
    val center: Vec2,
    val radius: Double,
    val angleDeg: Double,
    val diameter: Boolean = false,
    override val style: DimensionStyle = DimensionStyle(),
    override val id: String = newDimensionId(),
) : Dimension {

    override fun measure(): Double = if (diameter) radius * 2 else radius

    override fun text(formatter: MeasurementFormatter): String =
        style.overrideText ?: formatter
            .withPrecision(linear = style.precision)
            .formatLinear(
                modelValue = measure(),
                prefix = if (diameter) "Ø" else "R",
                tolerance = style.tolerance,
            )

    override fun geometry(formatter: MeasurementFormatter): DimensionGeometry {
        val direction = Vec2.polar(Vec2.ZERO, ArcMath.degToRad(angleDeg), 1.0)
        val onCircle = center + direction * radius
        val opposite = center - direction * radius

        val segments = mutableListOf<DimSegment>()
        val arrows = mutableListOf<Arrowhead>()

        if (diameter) {
            // La quota diametrale attraversa il cerchio: due frecce, una per parte.
            segments += DimSegment(opposite, onCircle)
            arrows += buildArrowhead(onCircle, direction, style)
            arrows += buildArrowhead(opposite, -direction, style)
        } else {
            segments += DimSegment(center, onCircle)
            arrows += buildArrowhead(onCircle, direction, style)
        }

        // Il testo esce dalla circonferenza con un breve tratto orizzontale di richiamo,
        // cosi' resta leggibile anche su cerchi piccoli, dove all'interno non ci starebbe.
        val leaderEnd = onCircle + direction * (style.effectiveArrowSize * 2)
        segments += DimSegment(onCircle, leaderEnd)

        val label = text(formatter)
        val textWidth = label.length * style.effectiveTextHeight * 0.6
        val pointsLeft = direction.x < 0
        val textAnchor = leaderEnd + Vec2(if (pointsLeft) -textWidth / 2 else textWidth / 2, 0.0)

        return DimensionGeometry(
            segments = segments,
            arrows = arrows,
            text = DimensionText(
                value = label,
                position = textAnchor + Vec2(0.0, style.effectiveTextGap + style.effectiveTextHeight / 2),
                height = style.effectiveTextHeight,
                rotationDeg = 0.0,
            ),
        )
    }
}

/**
 * Quota ordinata: distanza di un punto da un'origine lungo un solo asse. In cantiere e' il
 * modo piu' rapido per riportare una serie di fori o di montanti rispetto a un filo fisso.
 */
data class OrdinateDimension(
    val origin: Vec2,
    val feature: Vec2,
    val leaderEnd: Vec2,
    val axis: OrdinateAxis = OrdinateAxis.X,
    override val style: DimensionStyle = DimensionStyle(),
    override val id: String = newDimensionId(),
) : Dimension {

    override fun measure(): Double = when (axis) {
        OrdinateAxis.X -> feature.x - origin.x
        OrdinateAxis.Y -> feature.y - origin.y
    }

    override fun text(formatter: MeasurementFormatter): String =
        style.overrideText ?: formatter
            .withPrecision(linear = style.precision)
            .formatLinear(measure(), tolerance = style.tolerance)

    override fun geometry(formatter: MeasurementFormatter): DimensionGeometry {
        // Richiamo a gomito: tratto ortogonale all'asse quotato, poi tratto verso il testo.
        val elbow = when (axis) {
            OrdinateAxis.X -> Vec2(feature.x, leaderEnd.y)
            OrdinateAxis.Y -> Vec2(leaderEnd.x, feature.y)
        }
        val segments = listOf(
            DimSegment(feature, elbow),
            DimSegment(elbow, leaderEnd),
        )
        val textOffset = when (axis) {
            OrdinateAxis.X -> Vec2(0.0, style.effectiveTextGap + style.effectiveTextHeight / 2)
            OrdinateAxis.Y -> Vec2(style.effectiveTextGap + style.effectiveTextHeight, 0.0)
        }
        return DimensionGeometry(
            segments = segments,
            text = DimensionText(
                value = text(formatter),
                position = leaderEnd + textOffset,
                height = style.effectiveTextHeight,
                rotationDeg = if (axis == OrdinateAxis.X) 0.0 else 90.0,
            ),
        )
    }
}

/** Punta di freccia con vertice in [tip], rivolta verso [outward]. */
internal fun buildArrowhead(tip: Vec2, outward: Vec2, style: DimensionStyle): Arrowhead {
    val direction = outward.normalized().takeIf { it.length > 0.5 } ?: Vec2(1.0, 0.0)
    val baseCenter = tip - direction * style.effectiveArrowSize
    val half = direction.leftNormal * (style.effectiveArrowSize / 3.0)
    return Arrowhead(tip, (baseCenter + half) to (baseCenter - half))
}

/**
 * Ruota il testo in modo che resti leggibile da sinistra a destra: una quota inclinata di
 * 200 gradi va scritta a 20, non a testa in giu'.
 */
internal fun readableAngle(degrees: Double): Double {
    val normalized = ArcMath.normalizeDeg(degrees)
    return if (normalized > 90.0 && normalized <= 270.0) normalized - 180.0 else normalized
}

private val dimensionCounter = java.util.concurrent.atomic.AtomicInteger()

internal fun newDimensionId(): String = "dim-${dimensionCounter.incrementAndGet()}"
