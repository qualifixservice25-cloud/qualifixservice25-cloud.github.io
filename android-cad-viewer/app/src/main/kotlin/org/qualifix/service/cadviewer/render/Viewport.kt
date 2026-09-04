package org.qualifix.service.cadviewer.render

import org.qualifix.cad.core.geometry.Bounds
import org.qualifix.cad.core.geometry.Vec2
import kotlin.math.max
import kotlin.math.min

/**
 * Finestra di vista sul disegno: converte fra coordinate modello e pixel dello schermo.
 *
 * Due punti fissi di ogni CAD, che qui vanno rispettati o l'app "sembra rotta" a chi la usa:
 * l'asse Y del disegno cresce verso l'alto mentre quello dello schermo cresce verso il basso,
 * e la scala e' isotropa (mai schiacciare un asse, altrimenti i cerchi diventano ellissi e le
 * quote mentono).
 */
class Viewport {

    /** Pixel per unita' di disegno. */
    var scale: Double = 1.0
        private set

    /** Punto del disegno mostrato al centro della vista. */
    var center: Vec2 = Vec2.ZERO
        private set

    var viewWidth: Int = 0
        private set

    var viewHeight: Int = 0
        private set

    fun setViewSize(width: Int, height: Int) {
        viewWidth = width
        viewHeight = height
    }

    fun screenX(worldX: Double): Float = ((worldX - center.x) * scale + viewWidth / 2.0).toFloat()

    fun screenY(worldY: Double): Float = (viewHeight / 2.0 - (worldY - center.y) * scale).toFloat()

    fun toWorld(screenX: Float, screenY: Float): Vec2 = Vec2(
        x = center.x + (screenX - viewWidth / 2.0) / scale,
        y = center.y - (screenY - viewHeight / 2.0) / scale,
    )

    /** Lunghezza in unita' modello di [pixels] pixel: serve a tenere costante il raggio di snap. */
    fun toModelLength(pixels: Float): Double = pixels / scale

    /** Lunghezza in pixel di una misura del disegno: serve al culling per dimensione. */
    fun toScreenLength(modelLength: Double): Double = modelLength * scale

    /** Porzione di disegno attualmente visibile, usata per scartare le entita' fuori campo. */
    fun visibleBounds(): Bounds {
        if (viewWidth == 0 || viewHeight == 0) return Bounds.EMPTY
        val halfWidth = viewWidth / 2.0 / scale
        val halfHeight = viewHeight / 2.0 / scale
        return Bounds(
            center.x - halfWidth,
            center.y - halfHeight,
            center.x + halfWidth,
            center.y + halfHeight,
        )
    }

    fun pan(deltaScreenX: Float, deltaScreenY: Float) {
        center = Vec2(center.x - deltaScreenX / scale, center.y + deltaScreenY / scale)
    }

    /** Zoom mantenendo fermo il punto del disegno che sta sotto le dita. */
    fun zoomAround(factor: Double, focusScreenX: Float, focusScreenY: Float) {
        val focusWorld = toWorld(focusScreenX, focusScreenY)
        scale = (scale * factor).coerceIn(MIN_SCALE, MAX_SCALE)
        val afterWorld = toWorld(focusScreenX, focusScreenY)
        center = Vec2(
            center.x + (focusWorld.x - afterWorld.x),
            center.y + (focusWorld.y - afterWorld.y),
        )
    }

    /** Inquadra tutto il disegno, con un margine sui bordi. */
    fun fit(bounds: Bounds, paddingFraction: Double = 0.06) {
        if (bounds.isEmpty || viewWidth == 0 || viewHeight == 0) return
        center = bounds.center
        val usableWidth = viewWidth * (1 - 2 * paddingFraction)
        val usableHeight = viewHeight * (1 - 2 * paddingFraction)
        val scaleX = if (bounds.width > 0) usableWidth / bounds.width else Double.MAX_VALUE
        val scaleY = if (bounds.height > 0) usableHeight / bounds.height else Double.MAX_VALUE
        val fitted = min(scaleX, scaleY)
        // Un disegno degenere (un solo punto, una sola linea) non deve mandare la scala a infinito.
        scale = if (fitted.isFinite()) fitted.coerceIn(MIN_SCALE, MAX_SCALE) else 1.0
    }

    fun copyFrom(other: Viewport) {
        scale = other.scale
        center = other.center
    }

    companion object {
        const val MIN_SCALE = 1e-6
        const val MAX_SCALE = 1e6

        /** Raggio di aggancio in pixel: circa la meta' del polpastrello medio. */
        const val SNAP_RADIUS_PX = 36f

        fun clampZoomStep(step: Double): Double = max(0.1, min(10.0, step))
    }
}
