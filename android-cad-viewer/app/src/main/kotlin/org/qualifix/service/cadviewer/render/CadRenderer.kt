package org.qualifix.service.cadviewer.render

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import org.qualifix.cad.core.dimension.DimensionGeometry
import org.qualifix.cad.core.geometry.ArcSegment
import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.model.AciColor
import org.qualifix.cad.core.model.AciPalette
import org.qualifix.cad.core.model.CadArc
import org.qualifix.cad.core.model.CadCircle
import org.qualifix.cad.core.model.CadEllipse
import org.qualifix.cad.core.model.CadEntity
import org.qualifix.cad.core.model.CadLayer
import org.qualifix.cad.core.model.CadLine
import org.qualifix.cad.core.model.CadPoint
import org.qualifix.cad.core.model.CadPolyline
import org.qualifix.cad.core.model.CadSolid
import org.qualifix.cad.core.model.CadText
import org.qualifix.cad.core.model.PolylinePiece
import org.qualifix.cad.core.model.TextHorizontalAlign
import org.qualifix.cad.core.snap.SnapResult

/**
 * Disegna il documento sul Canvas di Android.
 *
 * Scelte che tengono in piedi il rendering su un telefono di fascia media:
 * - **culling**: si scartano subito le entita' fuori dalla porzione inquadrata;
 * - **soglia di dettaglio**: cio' che a schermo occuperebbe meno di un paio di pixel non viene
 *   disegnato, perche' costa quanto un'entita' grande e non si vede;
 * - **spessori in pixel**: le linee restano dello stesso spessore a ogni zoom, come nei CAD,
 *   invece di ingrassare avvicinandosi.
 */
class CadRenderer {

    var darkBackground: Boolean = true

    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val path = Path()
    private val arcRect = RectF()

    /** Colore di fondo coerente con il tema: il "tavolo da disegno" su cui si legge il tratto. */
    val backgroundColor: Int
        get() = if (darkBackground) Color.rgb(16, 20, 24) else Color.rgb(250, 250, 248)

    private val quoteColor: Int
        get() = if (darkBackground) Color.rgb(255, 196, 87) else Color.rgb(176, 96, 12)

    private val snapColor: Int
        get() = if (darkBackground) Color.rgb(88, 224, 214) else Color.rgb(0, 128, 122)

    fun drawScene(
        canvas: Canvas,
        viewport: Viewport,
        entities: List<CadEntity>,
        layers: Map<String, CadLayer>,
        dimensions: List<DimensionGeometry>,
        pendingPoints: List<Vec2> = emptyList(),
        snap: SnapResult? = null,
        lineWidthPx: Float = 1.6f,
    ) {
        canvas.drawColor(backgroundColor)
        val visible = viewport.visibleBounds()

        strokePaint.strokeWidth = lineWidthPx
        for (entity in entities) {
            if (!entity.bounds.intersects(visible)) continue
            if (isTooSmallToSee(entity, viewport)) continue
            drawEntity(canvas, viewport, entity, layers)
        }

        for (geometry in dimensions) {
            if (!geometry.bounds.intersects(visible)) continue
            drawDimension(canvas, viewport, geometry)
        }

        drawPendingPoints(canvas, viewport, pendingPoints)
        snap?.let { drawSnapMarker(canvas, viewport, it) }
    }

    private fun isTooSmallToSee(entity: CadEntity, viewport: Viewport): Boolean {
        val bounds = entity.bounds
        if (entity is CadPoint) return false
        val widthPx = viewport.toScreenLength(bounds.width)
        val heightPx = viewport.toScreenLength(bounds.height)
        return widthPx < MIN_VISIBLE_PX && heightPx < MIN_VISIBLE_PX
    }

    // ---------------------------------------------------------------- entita'

    private fun drawEntity(
        canvas: Canvas,
        viewport: Viewport,
        entity: CadEntity,
        layers: Map<String, CadLayer>,
    ) {
        val layerColor = layers[entity.layer]?.color ?: AciColor(7)
        val color = AciPalette.resolve(entity.color, layerColor, darkBackground) or ALPHA_OPAQUE
        strokePaint.color = color
        fillPaint.color = color
        textPaint.color = color

        when (entity) {
            is CadLine -> canvas.drawLine(
                viewport.screenX(entity.start.x),
                viewport.screenY(entity.start.y),
                viewport.screenX(entity.end.x),
                viewport.screenY(entity.end.y),
                strokePaint,
            )

            is CadPoint -> canvas.drawCircle(
                viewport.screenX(entity.position.x),
                viewport.screenY(entity.position.y),
                POINT_RADIUS_PX,
                fillPaint,
            )

            is CadCircle -> canvas.drawCircle(
                viewport.screenX(entity.center.x),
                viewport.screenY(entity.center.y),
                viewport.toScreenLength(entity.radius).toFloat(),
                strokePaint,
            )

            is CadArc -> drawArc(canvas, viewport, entity.asSegment())

            is CadPolyline -> drawPolyline(canvas, viewport, entity)

            is CadEllipse -> {
                val points = entity.flatten()
                path.rewind()
                points.forEachIndexed { index, point ->
                    val x = viewport.screenX(point.x)
                    val y = viewport.screenY(point.y)
                    if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                canvas.drawPath(path, strokePaint)
            }

            is CadSolid -> {
                path.rewind()
                entity.points.forEachIndexed { index, point ->
                    val x = viewport.screenX(point.x)
                    val y = viewport.screenY(point.y)
                    if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                path.close()
                canvas.drawPath(path, fillPaint)
            }

            is CadText -> drawText(canvas, viewport, entity)

            // INSERT e DIMENSION arrivano gia' risolti in geometria da CadDocument.
            else -> Unit
        }
    }

    private fun drawPolyline(canvas: Canvas, viewport: Viewport, polyline: CadPolyline) {
        path.rewind()
        var started = false
        for (piece in polyline.pieces()) {
            when (piece) {
                is PolylinePiece.Line -> {
                    if (!started) {
                        path.moveTo(viewport.screenX(piece.start.x), viewport.screenY(piece.start.y))
                        started = true
                    }
                    path.lineTo(viewport.screenX(piece.end.x), viewport.screenY(piece.end.y))
                }

                is PolylinePiece.Arc -> {
                    val arc = piece.arc
                    if (!started) {
                        path.moveTo(
                            viewport.screenX(arc.startPoint.x),
                            viewport.screenY(arc.startPoint.y),
                        )
                        started = true
                    }
                    setArcRect(viewport, arc)
                    // Sullo schermo l'asse Y e' rovesciato: un arco antiorario nel disegno
                    // si percorre in senso orario in coordinate schermo.
                    path.arcTo(arcRect, (-arc.startDeg).toFloat(), (-arc.sweepDeg).toFloat(), false)
                }
            }
        }
        if (polyline.closed) path.close()
        canvas.drawPath(path, strokePaint)
    }

    private fun drawArc(canvas: Canvas, viewport: Viewport, arc: ArcSegment) {
        setArcRect(viewport, arc)
        canvas.drawArc(arcRect, (-arc.startDeg).toFloat(), (-arc.sweepDeg).toFloat(), false, strokePaint)
    }

    private fun setArcRect(viewport: Viewport, arc: ArcSegment) {
        val radiusPx = viewport.toScreenLength(arc.radius).toFloat()
        val cx = viewport.screenX(arc.center.x)
        val cy = viewport.screenY(arc.center.y)
        arcRect.set(cx - radiusPx, cy - radiusPx, cx + radiusPx, cy + radiusPx)
    }

    private fun drawText(canvas: Canvas, viewport: Viewport, text: CadText) {
        val sizePx = viewport.toScreenLength(text.height).toFloat()
        // Sotto una certa dimensione il testo e' un rumore grigio: meglio non disegnarlo affatto.
        if (sizePx < MIN_TEXT_PX) return
        textPaint.textSize = sizePx
        textPaint.textAlign = when (text.align) {
            TextHorizontalAlign.LEFT -> Paint.Align.LEFT
            TextHorizontalAlign.CENTER -> Paint.Align.CENTER
            TextHorizontalAlign.RIGHT -> Paint.Align.RIGHT
        }
        val x = viewport.screenX(text.position.x)
        val y = viewport.screenY(text.position.y)
        canvas.save()
        // La rotazione del CAD e' antioraria, quella del Canvas oraria.
        canvas.rotate(-text.rotationDeg.toFloat(), x, y)
        canvas.drawText(text.value, x, y, textPaint)
        canvas.restore()
    }

    // ---------------------------------------------------------------- quote

    private fun drawDimension(canvas: Canvas, viewport: Viewport, geometry: DimensionGeometry) {
        strokePaint.color = quoteColor or ALPHA_OPAQUE
        fillPaint.color = quoteColor or ALPHA_OPAQUE
        textPaint.color = quoteColor or ALPHA_OPAQUE

        for (segment in geometry.segments) {
            canvas.drawLine(
                viewport.screenX(segment.start.x),
                viewport.screenY(segment.start.y),
                viewport.screenX(segment.end.x),
                viewport.screenY(segment.end.y),
                strokePaint,
            )
        }

        for (arrow in geometry.arrows) {
            path.rewind()
            arrow.points.forEachIndexed { index, point ->
                val x = viewport.screenX(point.x)
                val y = viewport.screenY(point.y)
                if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            path.close()
            canvas.drawPath(path, fillPaint)
        }

        for (arc in geometry.arcs) {
            drawArc(canvas, viewport, arc)
        }

        val text = geometry.text
        val sizePx = viewport.toScreenLength(text.height).toFloat()
            // Le quote dell'utente restano leggibili anche a zoom lontano: sono il motivo
            // per cui sta guardando il disegno.
            .coerceIn(MIN_QUOTE_TEXT_PX, MAX_QUOTE_TEXT_PX)
        textPaint.textSize = sizePx
        textPaint.textAlign = Paint.Align.CENTER
        val x = viewport.screenX(text.position.x)
        val y = viewport.screenY(text.position.y)
        val metrics = textPaint.fontMetrics
        canvas.save()
        canvas.rotate(-text.rotationDeg.toFloat(), x, y)
        // Il punto della quota e' il centro del testo, drawText parte dalla linea di base.
        canvas.drawText(text.value, x, y - (metrics.ascent + metrics.descent) / 2f, textPaint)
        canvas.restore()
    }

    // ---------------------------------------------------------------- indicatori

    private fun drawPendingPoints(canvas: Canvas, viewport: Viewport, points: List<Vec2>) {
        if (points.isEmpty()) return
        fillPaint.color = snapColor or ALPHA_OPAQUE
        strokePaint.color = snapColor or ALPHA_OPAQUE
        var previous: Vec2? = null
        for (point in points) {
            val x = viewport.screenX(point.x)
            val y = viewport.screenY(point.y)
            canvas.drawCircle(x, y, PENDING_RADIUS_PX, fillPaint)
            previous?.let {
                canvas.drawLine(viewport.screenX(it.x), viewport.screenY(it.y), x, y, strokePaint)
            }
            previous = point
        }
    }

    /**
     * Marcatore di aggancio: un quadrato attorno al punto, come nei CAD desktop, piu' la
     * sigla del tipo. Senza questo riscontro visivo l'utente non sa mai su cosa ha agganciato.
     */
    private fun drawSnapMarker(canvas: Canvas, viewport: Viewport, snap: SnapResult) {
        val x = viewport.screenX(snap.point.x)
        val y = viewport.screenY(snap.point.y)
        strokePaint.color = snapColor or ALPHA_OPAQUE
        strokePaint.strokeWidth = 2f
        canvas.drawRect(
            x - SNAP_MARKER_PX,
            y - SNAP_MARKER_PX,
            x + SNAP_MARKER_PX,
            y + SNAP_MARKER_PX,
            strokePaint,
        )
        textPaint.color = snapColor or ALPHA_OPAQUE
        textPaint.textSize = SNAP_LABEL_PX
        textPaint.textAlign = Paint.Align.LEFT
        canvas.drawText(snap.type.label, x + SNAP_MARKER_PX * 1.6f, y - SNAP_MARKER_PX, textPaint)
    }

    private companion object {
        const val ALPHA_OPAQUE = 0xFF shl 24
        const val MIN_VISIBLE_PX = 2.0
        const val MIN_TEXT_PX = 7f
        const val MIN_QUOTE_TEXT_PX = 11f
        const val MAX_QUOTE_TEXT_PX = 64f
        const val POINT_RADIUS_PX = 2.5f
        const val PENDING_RADIUS_PX = 5f
        const val SNAP_MARKER_PX = 12f
        const val SNAP_LABEL_PX = 26f
    }
}
