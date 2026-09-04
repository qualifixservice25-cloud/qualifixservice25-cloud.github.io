package org.qualifix.service.cadviewer.render

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import org.qualifix.cad.core.dimension.DimensionGeometry
import org.qualifix.cad.core.geometry.Bounds
import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.model.CadEntity
import org.qualifix.cad.core.model.CadLayer
import org.qualifix.cad.core.snap.SnapEngine
import org.qualifix.cad.core.snap.SnapResult
import org.qualifix.cad.core.snap.SnapType

/** Tutto cio' che serve per disegnare un fotogramma. */
data class CadScene(
    val documentId: Long = 0L,
    val entities: List<CadEntity> = emptyList(),
    val layers: Map<String, CadLayer> = emptyMap(),
    val dimensions: List<DimensionGeometry> = emptyList(),
    val pendingPoints: List<Vec2> = emptyList(),
    val bounds: Bounds = Bounds.EMPTY,
    val snapTypes: Set<SnapType> = SnapType.DEFAULTS,
    val darkBackground: Boolean = true,
) {
    companion object {
        val EMPTY = CadScene()
    }
}

/**
 * Vista del disegno: rendering e gesti.
 *
 * Il modello di interazione e' quello che funziona con una mano sola in cantiere:
 * - senza uno strumento attivo, un dito trascina il disegno;
 * - con uno strumento di quotatura attivo, un dito posiziona il mirino e l'aggancio viene
 *   mostrato mentre si trascina, cosi' l'utente vede *dove* andra' il punto prima di alzare
 *   il dito; il punto si conferma sollevando;
 * - due dita fanno sempre zoom e spostamento, qualunque sia lo strumento.
 */
class CadView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    val viewport = Viewport()
    private val renderer = CadRenderer()

    private var snapEngine = SnapEngine(emptyList())
    private var snapEngineSource: List<CadEntity>? = null
    private var previewSnap: SnapResult? = null
    private var fittedDocumentId: Long? = null

    /** Strumento di quotatura attivo: cambia il significato del trascinamento a un dito. */
    var pickingEnabled: Boolean = false

    var onPointPicked: ((Vec2) -> Unit)? = null
    var onSnapPreview: ((SnapResult?) -> Unit)? = null
    var onScaleChanged: ((Double) -> Unit)? = null

    var scene: CadScene = CadScene.EMPTY
        set(value) {
            field = value
            renderer.darkBackground = value.darkBackground
            if (value.entities !== snapEngineSource) {
                snapEngine = SnapEngine(value.entities)
                snapEngineSource = value.entities
            }
            // Un documento nuovo va inquadrato una volta sola: rifarlo a ogni fotogramma
            // riporterebbe l'utente indietro a ogni quota aggiunta.
            if (value.documentId != fittedDocumentId && !value.bounds.isEmpty && width > 0) {
                viewport.fit(value.bounds)
                fittedDocumentId = value.documentId
                onScaleChanged?.invoke(viewport.scale)
            }
            invalidate()
        }

    private val scaleDetector = ScaleGestureDetector(
        context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                viewport.zoomAround(
                    factor = Viewport.clampZoomStep(detector.scaleFactor.toDouble()),
                    focusScreenX = detector.focusX,
                    focusScreenY = detector.focusY,
                )
                onScaleChanged?.invoke(viewport.scale)
                invalidate()
                return true
            }
        },
    )

    private var lastX = 0f
    private var lastY = 0f
    private var lastPointerCount = 0

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        viewport.setViewSize(w, h)
        if (fittedDocumentId != scene.documentId && !scene.bounds.isEmpty) {
            viewport.fit(scene.bounds)
            fittedDocumentId = scene.documentId
            onScaleChanged?.invoke(viewport.scale)
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        renderer.drawScene(
            canvas = canvas,
            viewport = viewport,
            entities = scene.entities,
            layers = scene.layers,
            dimensions = scene.dimensions,
            pendingPoints = scene.pendingPoints,
            snap = previewSnap,
        )
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)

        val pointerCount = event.pointerCount
        val focusX = averageX(event)
        val focusY = averageY(event)

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                lastX = focusX
                lastY = focusY
                lastPointerCount = pointerCount
                if (pickingEnabled && pointerCount == 1) updatePreview(focusX, focusY)
            }

            MotionEvent.ACTION_MOVE -> {
                // Al cambio del numero di dita il centroide salta: si riparte da capo
                // invece di trascinare il disegno di colpo.
                if (pointerCount != lastPointerCount) {
                    lastX = focusX
                    lastY = focusY
                    lastPointerCount = pointerCount
                    return true
                }
                val dx = focusX - lastX
                val dy = focusY - lastY

                if (pickingEnabled && pointerCount == 1) {
                    updatePreview(focusX, focusY)
                } else if (!scaleDetector.isInProgress || pointerCount >= 2) {
                    viewport.pan(dx, dy)
                    invalidate()
                }
                lastX = focusX
                lastY = focusY
            }

            MotionEvent.ACTION_UP -> {
                if (pickingEnabled && lastPointerCount == 1) {
                    val world = viewport.toWorld(focusX, focusY)
                    onPointPicked?.invoke(previewSnap?.point ?: world)
                    clearPreview()
                }
                lastPointerCount = 0
            }

            MotionEvent.ACTION_POINTER_UP -> {
                lastPointerCount = pointerCount - 1
                lastX = focusX
                lastY = focusY
            }

            MotionEvent.ACTION_CANCEL -> {
                clearPreview()
                lastPointerCount = 0
            }
        }
        return true
    }

    /** Riporta la vista su tutto il disegno. */
    fun fitToDrawing() {
        if (scene.bounds.isEmpty) return
        viewport.fit(scene.bounds)
        onScaleChanged?.invoke(viewport.scale)
        invalidate()
    }

    fun zoomBy(factor: Double) {
        viewport.zoomAround(factor, width / 2f, height / 2f)
        onScaleChanged?.invoke(viewport.scale)
        invalidate()
    }

    private fun updatePreview(screenX: Float, screenY: Float) {
        val world = viewport.toWorld(screenX, screenY)
        val snap = snapEngine.snap(
            query = world,
            // Il raggio di aggancio e' fisso in pixel: a qualunque zoom il dito "prende"
            // sempre la stessa area di schermo.
            radius = viewport.toModelLength(Viewport.SNAP_RADIUS_PX),
            types = scene.snapTypes,
            from = scene.pendingPoints.lastOrNull(),
        )
        if (snap?.point != previewSnap?.point || snap?.type != previewSnap?.type) {
            previewSnap = snap
            onSnapPreview?.invoke(snap)
        }
        invalidate()
    }

    private fun clearPreview() {
        if (previewSnap != null) {
            previewSnap = null
            onSnapPreview?.invoke(null)
        }
        invalidate()
    }

    private fun averageX(event: MotionEvent): Float {
        var sum = 0f
        for (i in 0 until event.pointerCount) sum += event.getX(i)
        return sum / event.pointerCount
    }

    private fun averageY(event: MotionEvent): Float {
        var sum = 0f
        for (i in 0 until event.pointerCount) sum += event.getY(i)
        return sum / event.pointerCount
    }
}
