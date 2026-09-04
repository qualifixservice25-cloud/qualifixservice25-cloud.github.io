package org.qualifix.cad.core.model

import org.qualifix.cad.core.geometry.ArcMath
import org.qualifix.cad.core.geometry.Bounds
import org.qualifix.cad.core.geometry.Transform2D
import org.qualifix.cad.core.geometry.Vec2

data class CadLayer(
    val name: String,
    val color: AciColor = AciColor(7),
    val visible: Boolean = true,
    val frozen: Boolean = false,
    val locked: Boolean = false,
) {
    val isDrawable: Boolean get() = visible && !frozen
}

data class CadBlock(
    val name: String,
    val basePoint: Vec2,
    val entities: List<CadEntity>,
)

/**
 * Un disegno caricato in memoria. Immutabile: le quote aggiunte dall'utente vivono in un
 * layer separato gestito dall'app, cosi' il file di origine non viene mai alterato.
 */
class CadDocument(
    val layers: List<CadLayer>,
    val blocks: Map<String, CadBlock>,
    val entities: List<CadEntity>,
    val units: DrawingUnits = DrawingUnits.UNITLESS,
    /** Estensione dichiarata in header (`$EXTMIN`/`$EXTMAX`), se presente. */
    val declaredExtents: Bounds? = null,
    /** Decimali dichiarati dal disegno (`$LUPREC`), usati come default per le nuove quote. */
    val linearPrecision: Int = 2,
    val angularPrecision: Int = 0,
    val warnings: List<String> = emptyList(),
) {
    private val layersByName: Map<String, CadLayer> = layers.associateBy { it.name }

    fun layer(name: String): CadLayer? = layersByName[name]

    /**
     * Ingombro reale del disegno: si preferisce sempre la geometria all'header, perche'
     * `$EXTMIN`/`$EXTMAX` restano spesso fermi all'ultimo salvataggio del CAD desktop e
     * possono essere sballati o assenti.
     */
    val bounds: Bounds by lazy {
        val geometric = flattenedEntities().fold(Bounds.EMPTY) { acc, e -> acc.union(e.bounds) }
        if (!geometric.isEmpty) geometric else declaredExtents ?: Bounds.EMPTY
    }

    /** Tutte le entita' con i blocchi risolti e trasformati, pronte per rendering e snap. */
    fun flattenedEntities(includeInvisibleLayers: Boolean = false): List<CadEntity> {
        val output = mutableListOf<CadEntity>()
        for (entity in entities) {
            appendResolved(entity, Transform2D.IDENTITY, output, depth = 0, includeInvisibleLayers)
        }
        return output
    }

    private fun appendResolved(
        entity: CadEntity,
        transform: Transform2D,
        output: MutableList<CadEntity>,
        depth: Int,
        includeInvisibleLayers: Boolean,
    ) {
        if (!includeInvisibleLayers && layer(entity.layer)?.isDrawable == false) return
        if (depth > MAX_BLOCK_NESTING) return

        when (entity) {
            is CadInsert -> {
                val block = blocks[entity.blockName] ?: return
                val blockTransform = transform
                    .compose(Transform2D.insert(entity.position, entity.scale, entity.rotationDeg))
                    .compose(Transform2D.translation(-block.basePoint))
                for (child in block.entities) {
                    val inherited = if (child.color.isByBlock) entity.color else child.color
                    appendResolved(
                        entity = child.withColor(inherited),
                        transform = blockTransform,
                        output = output,
                        depth = depth + 1,
                        includeInvisibleLayers = includeInvisibleLayers,
                    )
                }
            }

            is CadDimensionRef -> {
                val block = entity.blockName?.let { blocks[it] }
                if (block == null) {
                    output += entity
                    return
                }
                // Le quote del file sono gia' disegnate nel loro blocco anonimo: si rende quello.
                for (child in block.entities) {
                    appendResolved(child, transform, output, depth + 1, includeInvisibleLayers)
                }
            }

            else -> output += transformEntity(entity, transform)
        }
    }

    companion object {
        /** Limite di sicurezza contro blocchi che si referenziano a vicenda in file corrotti. */
        const val MAX_BLOCK_NESTING = 16

        val EMPTY = CadDocument(emptyList(), emptyMap(), emptyList())
    }
}

private fun CadEntity.withColor(color: AciColor): CadEntity = when (this) {
    is CadLine -> copy(color = color)
    is CadPoint -> copy(color = color)
    is CadCircle -> copy(color = color)
    is CadArc -> copy(color = color)
    is CadPolyline -> copy(color = color)
    is CadEllipse -> copy(color = color)
    is CadText -> copy(color = color)
    is CadSolid -> copy(color = color)
    is CadInsert -> copy(color = color)
    is CadDimensionRef -> copy(color = color)
}

/**
 * Applica una trasformazione a un'entita'.
 *
 * Limite noto: con scala non uniforme cerchi e archi restano circolari usando la scala media,
 * invece di diventare ellissi. Sui disegni edili gli INSERT con scala anisotropa sono rari e
 * l'errore introdotto e' visibile solo su blocchi deliberatamente schiacciati.
 */
internal fun transformEntity(entity: CadEntity, t: Transform2D): CadEntity {
    if (t == Transform2D.IDENTITY) return entity
    return when (entity) {
        is CadLine -> entity.copy(start = t.apply(entity.start), end = t.apply(entity.end))
        is CadPoint -> entity.copy(position = t.apply(entity.position))
        is CadCircle -> entity.copy(
            center = t.apply(entity.center),
            radius = entity.radius * t.averageScale,
        )

        is CadArc -> {
            val rotation = t.rotationDeg
            val start = ArcMath.normalizeDeg(entity.startAngleDeg + rotation)
            val end = ArcMath.normalizeDeg(entity.endAngleDeg + rotation)
            entity.copy(
                center = t.apply(entity.center),
                radius = entity.radius * t.averageScale,
                // Con una trasformazione speculare il verso antiorario si inverte: si
                // riscrive l'arco scambiando gli estremi, per restare nella convenzione DXF.
                startAngleDeg = if (t.isMirrored) end else start,
                endAngleDeg = if (t.isMirrored) start else end,
            )
        }

        is CadPolyline -> entity.copy(
            vertices = entity.vertices.map {
                // Il bulge cambia segno se la trasformazione ribalta l'orientamento.
                it.copy(point = t.apply(it.point), bulge = if (t.isMirrored) -it.bulge else it.bulge)
            },
        )

        is CadEllipse -> entity.copy(
            center = t.apply(entity.center),
            majorAxis = t.applyDirection(entity.majorAxis),
        )

        is CadText -> entity.copy(
            position = t.apply(entity.position),
            height = entity.height * t.averageScale,
            rotationDeg = entity.rotationDeg + t.rotationDeg,
        )

        is CadSolid -> entity.copy(points = entity.points.map { t.apply(it) })

        is CadInsert -> entity.copy(
            position = t.apply(entity.position),
            scale = Vec2(entity.scale.x * t.averageScale, entity.scale.y * t.averageScale),
            rotationDeg = entity.rotationDeg + t.rotationDeg,
        )

        is CadDimensionRef -> entity.copy(insertPoint = t.apply(entity.insertPoint))
    }
}
