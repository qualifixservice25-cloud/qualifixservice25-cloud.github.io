package org.cadviewer.app

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.cadviewer.app.io.DrawingRepository
import org.cadviewer.app.io.UnsupportedDwgException
import org.cadviewer.app.render.Viewport
import org.cadviewer.core.dimension.Dimension
import org.cadviewer.core.dimension.DimensionStyle
import org.cadviewer.core.dimension.withStyle
import org.cadviewer.core.geometry.Bounds
import org.cadviewer.core.geometry.Vec2
import org.cadviewer.core.measure.MeasurementFormatter
import org.cadviewer.core.model.CadDocument
import org.cadviewer.core.model.CadEntity
import org.cadviewer.core.model.CadLayer
import org.cadviewer.core.model.DrawingUnits
import org.cadviewer.core.tool.CadTool
import org.cadviewer.core.tool.DimensionBuilder
import org.cadviewer.core.tool.PickedSegment
import org.cadviewer.core.tool.SegmentPicker
import java.util.Locale

data class CadUiState(
    val documentId: Long = 0L,
    val fileName: String? = null,
    val document: CadDocument = CadDocument.EMPTY,
    /** Entita' con i blocchi gia' risolti, layer spenti compresi. */
    val allEntities: List<CadEntity> = emptyList(),
    val hiddenLayers: Set<String> = emptySet(),
    val dimensions: List<Dimension> = emptyList(),
    val tool: CadTool = CadTool.PAN,
    val pendingPoints: List<Vec2> = emptyList(),
    /** Misura al volo: mostrata finche' non si tocca altro, non finisce fra le quote. */
    val quickMeasure: Dimension? = null,
    /**
     * Ultima linea toccata con lo strumento [CadTool.LINE]: e' il termine di paragone da cui
     * si misura la distanza al tocco successivo.
     */
    val lastPickedSegment: PickedSegment? = null,
    val displayUnits: DrawingUnits = DrawingUnits.UNITLESS,
    val precision: Int = 2,
    val style: DimensionStyle = DimensionStyle(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val notice: String? = null,
    val snapLabel: String? = null,
) {
    val formatter: MeasurementFormatter
        get() = MeasurementFormatter(
            drawingUnits = document.units,
            displayUnits = if (document.units == DrawingUnits.UNITLESS) DrawingUnits.UNITLESS else displayUnits,
            linearPrecision = precision,
            angularPrecision = 1,
            locale = Locale.getDefault(),
        )

    val layers: List<CadLayer> get() = document.layers

    val layersByName: Map<String, CadLayer> get() = document.layers.associateBy { it.name }

    val visibleEntities: List<CadEntity>
        get() = if (hiddenLayers.isEmpty()) {
            allEntities
        } else {
            allEntities.filter { it.layer !in hiddenLayers }
        }

    val bounds: Bounds get() = document.bounds

    val hasDrawing: Boolean get() = allEntities.isNotEmpty()

    /** Quante volte l'utente deve ancora toccare per completare la quota in corso. */
    val remainingPicks: Int get() = (tool.requiredPoints - pendingPoints.size).coerceAtLeast(0)
}

/**
 * Stato dell'applicazione: documento caricato, quote create, strumento attivo.
 *
 * Le quote vivono qui, fuori dal documento: il file aperto non viene mai modificato, e cio'
 * che l'utente aggiunge finisce nel disegno solo al momento dell'esportazione.
 */
class CadViewModel(application: Application) : AndroidViewModel(application) {

    private val _state = MutableStateFlow(CadUiState())
    val state: StateFlow<CadUiState> = _state.asStateFlow()

    /** Pixel per unita' di disegno, aggiornata dalla vista: serve a dare una tolleranza reale. */
    private var pixelsPerUnit: Double = 1.0

    fun open(uri: Uri) {
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            try {
                val loaded = withContext(Dispatchers.IO) {
                    DrawingRepository.load(getApplication(), uri)
                }
                val document = loaded.document
                val entities = withContext(Dispatchers.Default) {
                    document.flattenedEntities(includeInvisibleLayers = true)
                }
                _state.update { current ->
                    current.copy(
                        documentId = current.documentId + 1,
                        fileName = loaded.fileName,
                        document = document,
                        allEntities = entities,
                        hiddenLayers = document.layers.filterNot { it.isDrawable }.map { it.name }.toSet(),
                        dimensions = emptyList(),
                        pendingPoints = emptyList(),
                        quickMeasure = null,
                        lastPickedSegment = null,
                        tool = CadTool.PAN,
                        // Il disegno decide le unita': l'app non le sceglie al posto suo.
                        displayUnits = document.units,
                        precision = document.linearPrecision,
                        style = DimensionStyle.forDrawing(document.bounds),
                        isLoading = false,
                        error = null,
                        notice = document.warnings.firstOrNull(),
                    )
                }
            } catch (error: Exception) {
                _state.update { it.copy(isLoading = false, error = errorMessage(error)) }
            }
        }
    }

    private fun errorMessage(error: Exception): String = when (error) {
        is UnsupportedDwgException ->
            getApplication<Application>().getString(R.string.error_dwg_unsupported)
        else -> error.message ?: getApplication<Application>().getString(R.string.error_open_failed)
    }

    fun selectTool(tool: CadTool) {
        _state.update {
            it.copy(
                tool = if (it.tool == tool) CadTool.PAN else tool,
                pendingPoints = emptyList(),
                quickMeasure = null,
                lastPickedSegment = null,
                snapLabel = null,
            )
        }
    }

    /** Registra un punto toccato e, quando bastano, crea la quota. */
    fun pickPoint(point: Vec2) {
        val current = _state.value
        val tool = current.tool
        if (!tool.needsPicking) return
        if (tool == CadTool.LINE) {
            pickLine(point, current)
            return
        }

        val points = current.pendingPoints + point
        if (points.size < tool.requiredPoints) {
            _state.update { it.copy(pendingPoints = points) }
            return
        }

        val dimension = DimensionBuilder.build(
            tool = tool,
            points = points,
            style = current.style,
            entities = current.visibleEntities,
            circularTolerance = Viewport.SNAP_RADIUS_PX / pixelsPerUnit,
        )

        if (dimension == null) {
            _state.update {
                it.copy(
                    pendingPoints = emptyList(),
                    error = getApplication<Application>().getString(R.string.error_no_circle),
                )
            }
            return
        }

        _state.update {
            if (tool.isDimensionTool) {
                it.copy(dimensions = it.dimensions + dimension, pendingPoints = emptyList())
            } else {
                // La misura rapida resta a schermo ma non entra nel disegno.
                it.copy(quickMeasure = dimension, pendingPoints = emptyList())
            }
        }
    }

    /**
     * Tocco con lo strumento linea: la prima linea toccata viene misurata, dalla seconda in poi
     * si misura la distanza dalla precedente. La catena non si azzera, cosi' percorrendo una
     * stanza muro dopo muro ogni tocco da' la luce rispetto a quello appena letto.
     */
    private fun pickLine(point: Vec2, current: CadUiState) {
        val segment = SegmentPicker.nearest(
            entities = current.visibleEntities,
            near = point,
            tolerance = Viewport.SNAP_RADIUS_PX / pixelsPerUnit,
        )
        if (segment == null) {
            _state.update {
                it.copy(error = getApplication<Application>().getString(R.string.error_no_line))
            }
            return
        }

        val previous = current.lastPickedSegment
        val measure = if (previous == null) {
            DimensionBuilder.lengthOf(segment, current.style)
        } else {
            DimensionBuilder.distanceBetween(previous, segment, current.style)
        }

        _state.update {
            it.copy(
                lastPickedSegment = segment,
                // Su due linee che si incontrano non c'e' distanza: si tiene la misura
                // precedente a schermo e si dice perche', invece di mostrare uno zero.
                quickMeasure = measure ?: it.quickMeasure,
                error = if (measure == null) {
                    getApplication<Application>().getString(R.string.error_lines_meet)
                } else {
                    null
                },
            )
        }
    }

    fun cancelPending() {
        _state.update { it.copy(pendingPoints = emptyList(), snapLabel = null) }
    }

    fun undoLastDimension() {
        _state.update {
            when {
                it.pendingPoints.isNotEmpty() -> it.copy(pendingPoints = it.pendingPoints.dropLast(1))
                it.dimensions.isNotEmpty() -> it.copy(dimensions = it.dimensions.dropLast(1))
                else -> it.copy(quickMeasure = null, lastPickedSegment = null)
            }
        }
    }

    fun clearDimensions() {
        _state.update {
            it.copy(
                dimensions = emptyList(),
                pendingPoints = emptyList(),
                quickMeasure = null,
                lastPickedSegment = null,
            )
        }
    }

    fun toggleLayer(name: String) {
        _state.update {
            val hidden = if (name in it.hiddenLayers) it.hiddenLayers - name else it.hiddenLayers + name
            it.copy(hiddenLayers = hidden)
        }
    }

    fun setDisplayUnits(units: DrawingUnits) {
        _state.update { it.copy(displayUnits = units) }
    }

    /**
     * Cambia i decimali mostrati. Lo stile di quota e le quote gia' create vengono riallineati
     * insieme: i decimali di una quota li decide il suo stile (come DIMDEC nel CAD), quindi
     * senza questo passaggio il comando non avrebbe effetto su cio' che e' gia' sul disegno.
     */
    fun setPrecision(decimals: Int) {
        val precision = decimals.coerceIn(0, 4)
        _state.update { current ->
            val style = current.style.copy(precision = precision)
            current.copy(
                precision = precision,
                style = style,
                dimensions = current.dimensions.map { it.withStyle(style) },
                quickMeasure = current.quickMeasure?.withStyle(style),
            )
        }
    }

    fun setSnapLabel(label: String?) {
        if (_state.value.snapLabel != label) _state.update { it.copy(snapLabel = label) }
    }

    fun onScaleChanged(scale: Double) {
        pixelsPerUnit = if (scale > 0) scale else 1.0
    }

    fun exportDxf(uri: Uri) = export { current ->
        DrawingRepository.exportDxf(
            resolver = getApplication<Application>().contentResolver,
            uri = uri,
            document = current.document,
            dimensions = current.dimensions,
            formatter = current.formatter,
        )
    }

    fun exportPdf(uri: Uri) = export { current ->
        DrawingRepository.exportPdf(
            resolver = getApplication<Application>().contentResolver,
            uri = uri,
            document = current.document,
            dimensions = current.dimensions,
            formatter = current.formatter,
            hiddenLayers = current.hiddenLayers,
        )
    }

    private fun export(block: (CadUiState) -> Unit) {
        val current = _state.value
        if (!current.hasDrawing) return
        viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) { block(current) }
                _state.update {
                    it.copy(notice = getApplication<Application>().getString(R.string.export_done))
                }
            } catch (error: Exception) {
                _state.update {
                    it.copy(error = error.message ?: getApplication<Application>().getString(R.string.export_failed))
                }
            }
        }
    }

    fun dismissMessages() {
        _state.update { it.copy(error = null, notice = null) }
    }
}
