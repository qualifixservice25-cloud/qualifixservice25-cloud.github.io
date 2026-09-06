package org.cadviewer.core.dxf

import org.cadviewer.core.geometry.Bounds
import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.model.AciColor
import org.cadviewer.core.model.CadArc
import org.cadviewer.core.model.CadBlock
import org.cadviewer.core.model.CadCircle
import org.cadviewer.core.model.CadDimensionRef
import org.cadviewer.core.model.CadDocument
import org.cadviewer.core.model.CadEllipse
import org.cadviewer.core.model.CadEntity
import org.cadviewer.core.model.CadInsert
import org.cadviewer.core.model.CadLayer
import org.cadviewer.core.model.CadLine
import org.cadviewer.core.model.CadPoint
import org.cadviewer.core.model.CadPolyline
import org.cadviewer.core.model.CadSolid
import org.cadviewer.core.model.CadText
import org.cadviewer.core.model.DEFAULT_LAYER
import org.cadviewer.core.model.DrawingUnits
import org.cadviewer.core.model.PolylineVertex
import org.cadviewer.core.model.TextHorizontalAlign
import java.io.Reader

/**
 * Parser DXF ASCII.
 *
 * Principio di fondo: un disegno di cantiere reale contiene sempre qualcosa che non
 * conosciamo (entita' proprietarie, oggetti di applicativi verticali, tabelle custom).
 * Il parser non deve mai fallire per questo: le entita' ignote finiscono in [CadDocument.warnings]
 * e il resto del disegno si apre lo stesso.
 */
object DxfParser {

    fun parse(text: String): CadDocument = parse(DxfPairReader.read(text))

    fun parse(reader: Reader): CadDocument = parse(DxfPairReader.read(reader))

    fun parse(pairs: List<DxfPair>): CadDocument {
        val sections = splitSections(pairs)
        val warnings = mutableListOf<String>()

        val header = parseHeader(sections["HEADER"].orEmpty())
        val layers = parseLayers(sections["TABLES"].orEmpty())
        val blocks = parseBlocks(sections["BLOCKS"].orEmpty(), warnings)
        val entities = parseEntities(splitRecords(sections["ENTITIES"].orEmpty()), warnings)

        if (entities.isEmpty() && blocks.isEmpty()) {
            warnings += "Nessuna entita' trovata: il file potrebbe essere vuoto o non essere un DXF."
        }

        return CadDocument(
            layers = layers.ifEmpty { listOf(CadLayer(DEFAULT_LAYER)) },
            blocks = blocks,
            entities = entities,
            units = header.units,
            declaredExtents = header.extents,
            linearPrecision = header.linearPrecision,
            angularPrecision = header.angularPrecision,
            warnings = warnings,
        )
    }

    // ---------------------------------------------------------------- sezioni

    private fun splitSections(pairs: List<DxfPair>): Map<String, List<DxfPair>> {
        val sections = mutableMapOf<String, List<DxfPair>>()
        var index = 0
        while (index < pairs.size) {
            val pair = pairs[index]
            if (pair.code == 0 && pair.value == "SECTION") {
                val namePair = pairs.getOrNull(index + 1)
                val name = if (namePair?.code == 2) namePair.value else "UNKNOWN"
                val content = mutableListOf<DxfPair>()
                index += 2
                while (index < pairs.size && !(pairs[index].code == 0 && pairs[index].value == "ENDSEC")) {
                    content += pairs[index]
                    index++
                }
                sections[name] = content
            }
            index++
        }
        return sections
    }

    /** Spezza una sequenza di coppie in record, tagliando su ogni group code 0. */
    private fun splitRecords(pairs: List<DxfPair>): List<DxfRecord> {
        val records = mutableListOf<DxfRecord>()
        var current: MutableList<DxfPair>? = null
        var type: String? = null
        for (pair in pairs) {
            if (pair.code == 0) {
                if (type != null) records += DxfRecord(type, current.orEmpty())
                type = pair.value
                current = mutableListOf()
            } else {
                current?.add(pair)
            }
        }
        if (type != null) records += DxfRecord(type, current.orEmpty())
        return records
    }

    // ---------------------------------------------------------------- header

    private data class HeaderData(
        val units: DrawingUnits,
        val extents: Bounds?,
        val linearPrecision: Int,
        val angularPrecision: Int,
    )

    private fun parseHeader(pairs: List<DxfPair>): HeaderData {
        val variables = mutableMapOf<String, MutableList<DxfPair>>()
        var currentName: String? = null
        for (pair in pairs) {
            if (pair.code == 9) {
                currentName = pair.value.trim()
                variables[currentName] = mutableListOf()
            } else {
                currentName?.let { variables[it]?.add(pair) }
            }
        }

        fun point(name: String): Vec2? {
            val values = variables[name] ?: return null
            val x = values.firstOrNull { it.code == 10 }?.asDouble()
            val y = values.firstOrNull { it.code == 20 }?.asDouble()
            return if (x != null && y != null) Vec2(x, y) else null
        }

        val extMin = point("\$EXTMIN")
        val extMax = point("\$EXTMAX")
        val extents = if (extMin != null && extMax != null) {
            Bounds(extMin.x, extMin.y, extMax.x, extMax.y).takeIf { !it.isEmpty }
        } else {
            null
        }

        val unitsCode = variables["\$INSUNITS"]?.firstOrNull { it.code == 70 }?.asInt() ?: 0
        val linearPrecision = variables["\$LUPREC"]?.firstOrNull { it.code == 70 }?.asInt() ?: 2
        val angularPrecision = variables["\$AUPREC"]?.firstOrNull { it.code == 70 }?.asInt() ?: 0

        return HeaderData(
            units = DrawingUnits.fromCode(unitsCode),
            extents = extents,
            linearPrecision = linearPrecision.coerceIn(0, 8),
            angularPrecision = angularPrecision.coerceIn(0, 8),
        )
    }

    // ---------------------------------------------------------------- tabelle

    private fun parseLayers(pairs: List<DxfPair>): List<CadLayer> =
        splitRecords(pairs)
            .filter { it.type == "LAYER" && it.string(2) != null }
            .map { record ->
                val flags = record.int(70, 0)
                val rawColor = record.int(62, 7)
                CadLayer(
                    name = record.string(2)!!,
                    // Colore negativo nella tabella LAYER significa layer spento: il valore
                    // assoluto resta il colore, cosi' riaccenderlo dall'app non lo perde.
                    color = AciColor(kotlin.math.abs(rawColor)),
                    visible = rawColor >= 0,
                    frozen = (flags and 1) != 0,
                    locked = (flags and 4) != 0,
                )
            }
            .distinctBy { it.name }

    // ---------------------------------------------------------------- blocchi

    private fun parseBlocks(pairs: List<DxfPair>, warnings: MutableList<String>): Map<String, CadBlock> {
        val records = splitRecords(pairs)
        val blocks = mutableMapOf<String, CadBlock>()
        var index = 0
        while (index < records.size) {
            val record = records[index]
            if (record.type != "BLOCK") {
                index++
                continue
            }
            val name = record.string(2)
            if (name.isNullOrBlank()) {
                index++
                continue
            }
            val basePoint = Vec2(record.double(10, 0.0), record.double(20, 0.0))
            val body = mutableListOf<DxfRecord>()
            index++
            while (index < records.size && records[index].type != "ENDBLK") {
                body += records[index]
                index++
            }
            blocks[name] = CadBlock(name, basePoint, parseEntities(body, warnings))
        }
        return blocks
    }

    // ---------------------------------------------------------------- entita'

    private fun parseEntities(records: List<DxfRecord>, warnings: MutableList<String>): List<CadEntity> {
        val entities = mutableListOf<CadEntity>()
        val unsupported = mutableMapOf<String, Int>()
        var index = 0

        while (index < records.size) {
            val record = records[index]
            when (record.type) {
                "POLYLINE" -> {
                    // Polilinea vecchio stile: i vertici sono entita' VERTEX separate,
                    // chiuse da un SEQEND.
                    val vertices = mutableListOf<PolylineVertex>()
                    index++
                    while (index < records.size && records[index].type == "VERTEX") {
                        val vertex = records[index]
                        vertices += PolylineVertex(
                            point = Vec2(vertex.double(10, 0.0), vertex.double(20, 0.0)),
                            bulge = vertex.double(42, 0.0),
                        )
                        index++
                    }
                    if (index < records.size && records[index].type == "SEQEND") index++
                    if (vertices.size >= 2) {
                        entities += CadPolyline(
                            vertices = vertices,
                            closed = (record.int(70, 0) and 1) != 0,
                            layer = record.layerName(),
                            color = record.colorOrDefault(),
                        )
                    }
                }

                else -> {
                    val entity = convert(record)
                    if (entity != null) {
                        entities += entity
                    } else if (record.type !in IGNORED_SILENTLY) {
                        unsupported[record.type] = (unsupported[record.type] ?: 0) + 1
                    }
                    index++
                }
            }
        }

        unsupported.forEach { (type, count) ->
            warnings += "Entita' $type non supportata: $count occorrenze ignorate."
        }
        return entities
    }

    private fun convert(record: DxfRecord): CadEntity? = when (record.type) {
        "LINE" -> CadLine(
            start = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
            end = Vec2(record.double(11, 0.0), record.double(21, 0.0)),
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )

        "POINT" -> CadPoint(
            position = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )

        "CIRCLE" -> record.double(40)?.takeIf { it > 0 }?.let { radius ->
            CadCircle(
                center = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
                radius = radius,
                layer = record.layerName(),
                color = record.colorOrDefault(),
            )
        }

        "ARC" -> record.double(40)?.takeIf { it > 0 }?.let { radius ->
            CadArc(
                center = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
                radius = radius,
                startAngleDeg = record.double(50, 0.0),
                endAngleDeg = record.double(51, 360.0),
                layer = record.layerName(),
                color = record.colorOrDefault(),
            )
        }

        "ELLIPSE" -> CadEllipse(
            center = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
            majorAxis = Vec2(record.double(11, 1.0), record.double(21, 0.0)),
            axisRatio = record.double(40, 1.0),
            startParam = record.double(41, 0.0),
            endParam = record.double(42, 2 * Math.PI),
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )

        "LWPOLYLINE" -> parseLwPolyline(record)

        "TEXT" -> parseText(record)

        "MTEXT" -> parseMText(record)

        "SOLID", "3DFACE", "TRACE" -> parseSolid(record)

        "INSERT" -> record.string(2)?.let { name ->
            CadInsert(
                blockName = name,
                position = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
                scale = Vec2(record.double(41, 1.0), record.double(42, 1.0)),
                rotationDeg = record.double(50, 0.0),
                layer = record.layerName(),
                color = record.colorOrDefault(),
            )
        }

        "DIMENSION" -> CadDimensionRef(
            blockName = record.string(2),
            insertPoint = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
            measurement = record.double(42),
            overrideText = record.string(1)?.takeIf { it.isNotBlank() && it != "<>" },
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )

        else -> null
    }

    /**
     * LWPOLYLINE: le coppie 10/20 dei vertici e i bulge 42 vanno letti **in ordine**, perche'
     * un bulge appartiene al vertice che lo precede. Leggerli raggruppati per codice
     * disallineerebbe gli archi appena una polilinea mescola tratti retti e curvi.
     */
    private fun parseLwPolyline(record: DxfRecord): CadEntity? {
        val vertices = mutableListOf<PolylineVertex>()
        var pendingX: Double? = null
        for (pair in record.pairs) {
            when (pair.code) {
                10 -> pendingX = pair.asDouble()
                20 -> {
                    val x = pendingX
                    val y = pair.asDouble()
                    if (x != null && y != null) vertices += PolylineVertex(Vec2(x, y))
                    pendingX = null
                }

                42 -> {
                    val bulge = pair.asDouble()
                    if (bulge != null && vertices.isNotEmpty()) {
                        val last = vertices.removeAt(vertices.lastIndex)
                        vertices += last.copy(bulge = bulge)
                    }
                }
            }
        }
        if (vertices.size < 2) return null
        return CadPolyline(
            vertices = vertices,
            closed = (record.int(70, 0) and 1) != 0,
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )
    }

    private fun parseText(record: DxfRecord): CadEntity? {
        val value = record.string(1)?.let { unescapeText(it) } ?: return null
        if (value.isBlank()) return null
        val align = when (record.int(72, 0)) {
            1 -> TextHorizontalAlign.CENTER
            2 -> TextHorizontalAlign.RIGHT
            else -> TextHorizontalAlign.LEFT
        }
        // Con giustificazione diversa da sinistra il punto valido e' il secondo (11/21).
        val position = if (align == TextHorizontalAlign.LEFT || !record.has(11)) {
            Vec2(record.double(10, 0.0), record.double(20, 0.0))
        } else {
            Vec2(record.double(11, 0.0), record.double(21, 0.0))
        }
        return CadText(
            position = position,
            value = value,
            height = record.double(40, 2.5),
            rotationDeg = record.double(50, 0.0),
            align = align,
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )
    }

    private fun parseMText(record: DxfRecord): CadEntity? {
        // Il testo lungo arriva spezzato: i frammenti 3 precedono nell'ordine il finale 1.
        val raw = record.allStrings(3).joinToString("") + (record.string(1) ?: "")
        val value = stripMTextFormatting(raw)
        if (value.isBlank()) return null
        val attachment = record.int(71, 1)
        val align = when ((attachment - 1) % 3) {
            1 -> TextHorizontalAlign.CENTER
            2 -> TextHorizontalAlign.RIGHT
            else -> TextHorizontalAlign.LEFT
        }
        return CadText(
            position = Vec2(record.double(10, 0.0), record.double(20, 0.0)),
            value = value,
            height = record.double(40, 2.5),
            rotationDeg = record.double(50, 0.0),
            align = align,
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )
    }

    /**
     * SOLID e TRACE hanno i quattro vertici in ordine "a Z": il terzo e il quarto sono
     * scambiati rispetto al giro del contorno. Ignorarlo produce una clessidra al posto
     * del quadrilatero.
     */
    private fun parseSolid(record: DxfRecord): CadEntity? {
        val p1 = Vec2(record.double(10, 0.0), record.double(20, 0.0))
        val p2 = Vec2(record.double(11, 0.0), record.double(21, 0.0))
        val p3 = Vec2(record.double(12, 0.0), record.double(22, 0.0))
        val p4 = if (record.has(13)) Vec2(record.double(13, 0.0), record.double(23, 0.0)) else p3
        val points = if (p4.isCloseTo(p3)) listOf(p1, p2, p3) else listOf(p1, p2, p4, p3)
        return CadSolid(
            points = points,
            layer = record.layerName(),
            color = record.colorOrDefault(),
        )
    }

    // ---------------------------------------------------------------- testo

    /** Sequenze di escape del TEXT semplice: `%%d` grado, `%%c` diametro, `%%p` piu'/meno. */
    internal fun unescapeText(raw: String): String = raw
        .replace("%%d", "°")
        .replace("%%D", "°")
        .replace("%%c", "Ø")
        .replace("%%C", "Ø")
        .replace("%%p", "±")
        .replace("%%P", "±")
        .replace("%%%", "%")

    /**
     * Ripulisce il testo MTEXT dai codici di formattazione: font, altezze, colori, impilature
     * e raggruppamenti. Sul telefono la quota va letta, non tipografata come nel CAD desktop.
     */
    internal fun stripMTextFormatting(raw: String): String {
        var text = raw
        text = text.replace("\\P", "\n").replace("\\X", "\n")
        // Comandi con argomento chiuso da punto e virgola: \f..., \H2.5x, \C1, \W0.8, \A1
        text = text.replace(Regex("""\\[fFhHcCwWqQtTaA][^;\\]*;"""), "")
        // Frazioni impilate: \S sopra^sotto; -> sopra/sotto
        text = text.replace(Regex("""\\S([^^;]*)\^([^;]*);""")) { match ->
            val above = match.groupValues[1]
            val below = match.groupValues[2]
            if (below.isBlank()) above else "$above/$below"
        }
        text = text.replace("\\~", " ").replace("\\\\", "\\")
        text = text.replace(Regex("""[{}]"""), "")
        return unescapeText(text).trim()
    }

    private fun DxfRecord.layerName(): String = string(8)?.takeIf { it.isNotBlank() } ?: DEFAULT_LAYER

    private fun DxfRecord.colorOrDefault(): AciColor =
        int(62)?.let { AciColor(it) } ?: AciColor.DEFAULT

    /** Record strutturali o oggetti non geometrici: assenti dal disegno per definizione. */
    private val IGNORED_SILENTLY = setOf(
        "SEQEND", "ENDBLK", "BLOCK", "ATTDEF", "ATTRIB", "VIEWPORT", "TABLE", "ENDTAB",
    )
}
