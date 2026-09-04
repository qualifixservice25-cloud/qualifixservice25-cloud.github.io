package org.qualifix.cad.core.dxf

import org.qualifix.cad.core.dimension.Dimension
import org.qualifix.cad.core.dimension.DimensionStyle
import org.qualifix.cad.core.geometry.ArcMath
import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.measure.MeasurementFormatter
import org.qualifix.cad.core.model.CadArc
import org.qualifix.cad.core.model.CadCircle
import org.qualifix.cad.core.model.CadDocument
import org.qualifix.cad.core.model.CadEllipse
import org.qualifix.cad.core.model.CadEntity
import org.qualifix.cad.core.model.CadLayer
import org.qualifix.cad.core.model.CadLine
import org.qualifix.cad.core.model.CadPoint
import org.qualifix.cad.core.model.CadPolyline
import org.qualifix.cad.core.model.CadSolid
import org.qualifix.cad.core.model.CadText
import org.qualifix.cad.core.model.PolylineVertex
import org.qualifix.cad.core.model.TextHorizontalAlign
import java.util.Locale

/**
 * Scrittura di un DXF ASCII in formato R12 (AC1009).
 *
 * R12 e' volutamente il formato piu' vecchio: e' quello che *qualunque* CAD, gratuito o a
 * pagamento, riapre senza discussioni. L'export serve a portare in ufficio le quote prese in
 * cantiere, quindi la compatibilita' conta piu' della ricchezza del formato.
 *
 * Le quote vengono esportate come geometria (linee, frecce piene, testo) su un layer dedicato
 * invece che come entita' DIMENSION associative: una DIMENSION R12 richiede il blocco anonimo
 * che la disegna, e un blocco scritto male e' peggio di nessun blocco. Su un layer separato
 * restano isolabili e cancellabili in blocco nel CAD desktop.
 */
object DxfWriter {

    fun write(
        document: CadDocument,
        dimensions: List<Dimension> = emptyList(),
        formatter: MeasurementFormatter = MeasurementFormatter(document.units),
        quoteLayer: String = DimensionStyle.QUOTE_LAYER,
    ): String = buildString {
        val entities = document.flattenedEntities(includeInvisibleLayers = true)
        val dimensionEntities = dimensions.flatMap { toEntities(it, formatter, quoteLayer) }
        val layers = (document.layers + CadLayer(quoteLayer))
            .distinctBy { it.name }

        writeHeader(document)
        writeTables(layers)

        section("ENTITIES") {
            entities.forEach { writeEntity(it) }
            dimensionEntities.forEach { writeEntity(it) }
        }

        pair(0, "EOF")
    }

    /** Converte una quota nella geometria che la rappresenta sul file esportato. */
    fun toEntities(
        dimension: Dimension,
        formatter: MeasurementFormatter,
        layer: String = DimensionStyle.QUOTE_LAYER,
    ): List<CadEntity> {
        val geometry = dimension.geometry(formatter)
        val entities = mutableListOf<CadEntity>()

        geometry.segments.forEach { entities += CadLine(it.start, it.end, layer) }
        geometry.arrows.forEach {
            entities += CadSolid(listOf(it.tip, it.base.first, it.base.second), layer)
        }
        geometry.arcs.forEach {
            entities += CadArc(it.center, it.radius, it.startDeg, it.endDeg, layer)
        }
        entities += CadText(
            position = geometry.text.position,
            value = geometry.text.value,
            height = geometry.text.height,
            rotationDeg = geometry.text.rotationDeg,
            align = geometry.text.align,
            layer = layer,
        )
        return entities
    }

    // ---------------------------------------------------------------- sezioni

    private fun StringBuilder.writeHeader(document: CadDocument) {
        section("HEADER") {
            pair(9, "\$ACADVER")
            pair(1, "AC1009")
            pair(9, "\$INSUNITS")
            pair(70, document.units.code)
            val bounds = document.bounds
            if (!bounds.isEmpty) {
                pair(9, "\$EXTMIN")
                pair(10, bounds.minX)
                pair(20, bounds.minY)
                pair(9, "\$EXTMAX")
                pair(10, bounds.maxX)
                pair(20, bounds.maxY)
            }
            pair(9, "\$LUPREC")
            pair(70, document.linearPrecision)
        }
    }

    private fun StringBuilder.writeTables(layers: List<CadLayer>) {
        section("TABLES") {
            pair(0, "TABLE")
            pair(2, "LAYER")
            pair(70, layers.size)
            layers.forEach { layer ->
                pair(0, "LAYER")
                pair(2, layer.name)
                pair(70, if (layer.frozen) 1 else 0)
                // Colore negativo = layer spento, come nel file originale.
                pair(62, if (layer.visible) layer.color.index else -layer.color.index)
                pair(6, "CONTINUOUS")
            }
            pair(0, "ENDTAB")
        }
    }

    private inline fun StringBuilder.section(name: String, body: StringBuilder.() -> Unit) {
        pair(0, "SECTION")
        pair(2, name)
        body()
        pair(0, "ENDSEC")
    }

    // ---------------------------------------------------------------- entita'

    private fun StringBuilder.writeEntity(entity: CadEntity) {
        when (entity) {
            is CadLine -> {
                pair(0, "LINE")
                pair(8, entity.layer)
                point(10, entity.start)
                point(11, entity.end)
            }

            is CadPoint -> {
                pair(0, "POINT")
                pair(8, entity.layer)
                point(10, entity.position)
            }

            is CadCircle -> {
                pair(0, "CIRCLE")
                pair(8, entity.layer)
                point(10, entity.center)
                pair(40, entity.radius)
            }

            is CadArc -> {
                pair(0, "ARC")
                pair(8, entity.layer)
                point(10, entity.center)
                pair(40, entity.radius)
                pair(50, entity.startAngleDeg)
                pair(51, entity.endAngleDeg)
            }

            is CadPolyline -> writePolyline(entity.vertices, entity.closed, entity.layer)

            // R12 non conosce l'ellisse: si esporta discretizzata, cosi' resta visibile
            // ovunque invece di sparire.
            is CadEllipse -> writePolyline(
                vertices = entity.flatten().map { PolylineVertex(it) },
                closed = false,
                layer = entity.layer,
            )

            is CadText -> {
                pair(0, "TEXT")
                pair(8, entity.layer)
                point(10, entity.position)
                pair(40, entity.height)
                pair(1, escapeText(entity.value))
                if (entity.rotationDeg != 0.0) pair(50, entity.rotationDeg)
                val alignCode = when (entity.align) {
                    TextHorizontalAlign.LEFT -> 0
                    TextHorizontalAlign.CENTER -> 1
                    TextHorizontalAlign.RIGHT -> 2
                }
                if (alignCode != 0) {
                    pair(72, alignCode)
                    // Con giustificazione diversa da sinistra il punto di riferimento e'
                    // il secondo: se manca, molti CAD riallineano il testo a sinistra.
                    point(11, entity.position)
                }
            }

            is CadSolid -> {
                val points = entity.points
                if (points.size < 3) return
                pair(0, "SOLID")
                pair(8, entity.layer)
                point(10, points[0])
                point(11, points[1])
                // Ordine "a Z" del DXF: il terzo e il quarto vertice sono scambiati.
                if (points.size >= 4) {
                    point(12, points[3])
                    point(13, points[2])
                } else {
                    point(12, points[2])
                    point(13, points[2])
                }
            }

            // INSERT e DIMENSION arrivano qui gia' risolti da CadDocument.flattenedEntities().
            else -> Unit
        }
    }

    private fun StringBuilder.writePolyline(
        vertices: List<PolylineVertex>,
        closed: Boolean,
        layer: String,
    ) {
        if (vertices.size < 2) return
        pair(0, "POLYLINE")
        pair(8, layer)
        pair(66, 1) // "seguono entita' VERTEX": obbligatorio in R12
        point(10, Vec2.ZERO)
        pair(70, if (closed) 1 else 0)
        vertices.forEach { vertex ->
            pair(0, "VERTEX")
            pair(8, layer)
            point(10, vertex.point)
            if (vertex.bulge != 0.0) pair(42, vertex.bulge)
        }
        pair(0, "SEQEND")
        pair(8, layer)
    }

    // ---------------------------------------------------------------- utilita'

    private fun StringBuilder.pair(code: Int, value: String) {
        append(code).append('\n').append(value).append('\n')
    }

    private fun StringBuilder.pair(code: Int, value: Int) = pair(code, value.toString())

    private fun StringBuilder.pair(code: Int, value: Double) = pair(code, number(value))

    private fun StringBuilder.point(baseCode: Int, point: Vec2) {
        pair(baseCode, point.x)
        pair(baseCode + 10, point.y)
        pair(baseCode + 20, 0.0)
    }

    /** Il DXF vuole sempre il punto come separatore decimale, qualunque sia la lingua del telefono. */
    private fun number(value: Double): String = String.format(Locale.ROOT, "%.6f", value)

    /** Riporta i caratteri speciali alle sequenze `%%` che anche i CAD piu' vecchi capiscono. */
    private fun escapeText(value: String): String = value
        .replace("°", "%%d")
        .replace("Ø", "%%c")
        .replace("±", "%%p")
        .replace("\n", " ")

    /** Angolo normalizzato per la scrittura: evita valori negativi nei group code 50/51. */
    internal fun normalizedAngle(degrees: Double): Double = ArcMath.normalizeDeg(degrees)
}
