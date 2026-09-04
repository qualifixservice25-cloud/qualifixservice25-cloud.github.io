package org.qualifix.service.cadviewer.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Brightness6
import androidx.compose.material.icons.filled.CenterFocusStrong
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import org.qualifix.cad.core.geometry.Vec2
import org.qualifix.cad.core.model.DrawingUnits
import org.qualifix.cad.core.tool.CadTool
import org.qualifix.service.cadviewer.CadUiState
import org.qualifix.service.cadviewer.CadViewModel
import org.qualifix.service.cadviewer.R
import org.qualifix.service.cadviewer.render.CadScene
import org.qualifix.service.cadviewer.render.CadView

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CadScreen(
    viewModel: CadViewModel,
    darkTheme: Boolean,
    onToggleTheme: () -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val snackbarHost = remember { SnackbarHostState() }
    var showLayers by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }
    var cadView by remember { mutableStateOf<CadView?>(null) }

    val openLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let(viewModel::open)
    }
    val exportDxfLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/octet-stream"),
    ) { uri -> uri?.let(viewModel::exportDxf) }
    val exportPdfLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/pdf"),
    ) { uri -> uri?.let(viewModel::exportPdf) }

    val message = state.error ?: state.notice
    LaunchedEffect(message) {
        if (message != null) {
            snackbarHost.showSnackbar(message)
            viewModel.dismissMessages()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHost) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = state.fileName ?: stringResource(R.string.app_name),
                        maxLines = 1,
                        style = MaterialTheme.typography.titleMedium,
                    )
                },
                actions = {
                    IconButton(onClick = { openLauncher.launch(OPEN_MIME_TYPES) }) {
                        Icon(Icons.Filled.FolderOpen, stringResource(R.string.open_file))
                    }
                    IconButton(onClick = { cadView?.fitToDrawing() }, enabled = state.hasDrawing) {
                        Icon(Icons.Filled.CenterFocusStrong, stringResource(R.string.fit_view))
                    }
                    IconButton(onClick = { showLayers = true }, enabled = state.hasDrawing) {
                        Icon(Icons.Filled.Layers, stringResource(R.string.layers))
                    }
                    IconButton(onClick = onToggleTheme) {
                        Icon(Icons.Filled.Brightness6, stringResource(R.string.toggle_theme))
                    }
                    IconButton(
                        onClick = viewModel::undoLastDimension,
                        enabled = state.dimensions.isNotEmpty() || state.pendingPoints.isNotEmpty(),
                    ) {
                        Icon(Icons.Filled.Undo, stringResource(R.string.undo))
                    }
                    Box {
                        IconButton(onClick = { showMenu = true }, enabled = state.hasDrawing) {
                            Icon(Icons.Filled.MoreVert, stringResource(R.string.more_options))
                        }
                        DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.export_dxf)) },
                                onClick = {
                                    showMenu = false
                                    exportDxfLauncher.launch(suggestedName(state.fileName, "dxf"))
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.export_pdf)) },
                                onClick = {
                                    showMenu = false
                                    exportPdfLauncher.launch(suggestedName(state.fileName, "pdf"))
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.clear_dimensions)) },
                                onClick = {
                                    showMenu = false
                                    viewModel.clearDimensions()
                                },
                            )
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                DrawingCanvas(
                    state = state,
                    darkTheme = darkTheme,
                    onViewCreated = { cadView = it },
                    onPointPicked = viewModel::pickPoint,
                    onSnapLabel = viewModel::setSnapLabel,
                    onScaleChanged = viewModel::onScaleChanged,
                )
                if (!state.hasDrawing && !state.isLoading) {
                    EmptyState(onOpen = { openLauncher.launch(OPEN_MIME_TYPES) })
                }
                if (state.isLoading) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
            }

            ToolBar(selected = state.tool, enabled = state.hasDrawing, onSelect = viewModel::selectTool)

            StatusBar(
                state = state,
                onUnitsChange = viewModel::setDisplayUnits,
                onPrecisionChange = viewModel::setPrecision,
            )
        }
    }

    if (showLayers) {
        LayersSheet(
            layers = state.layers,
            hiddenLayers = state.hiddenLayers,
            onToggle = viewModel::toggleLayer,
            onDismiss = { showLayers = false },
        )
    }
}

@Composable
private fun DrawingCanvas(
    state: CadUiState,
    darkTheme: Boolean,
    onViewCreated: (CadView) -> Unit,
    onPointPicked: (Vec2) -> Unit,
    onSnapLabel: (String?) -> Unit,
    onScaleChanged: (Double) -> Unit,
) {
    // Entita' visibili e geometria delle quote si ricalcolano solo quando cambia qualcosa
    // che le riguarda: rifarlo a ogni fotogramma si sentirebbe su un disegno grande.
    val entities = remember(state.allEntities, state.hiddenLayers) { state.visibleEntities }
    val dimensionGeometries = remember(
        state.dimensions,
        state.quickMeasure,
        state.displayUnits,
        state.precision,
    ) {
        val formatter = state.formatter
        (state.dimensions + listOfNotNull(state.quickMeasure)).map { it.geometry(formatter) }
    }
    val scene = remember(state.documentId, entities, dimensionGeometries, state.pendingPoints, darkTheme) {
        CadScene(
            documentId = state.documentId,
            entities = entities,
            layers = state.layersByName,
            dimensions = dimensionGeometries,
            pendingPoints = state.pendingPoints,
            bounds = state.bounds,
            darkBackground = darkTheme,
        )
    }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            CadView(context).also { view ->
                view.onPointPicked = onPointPicked
                view.onSnapPreview = { snap -> onSnapLabel(snap?.type?.label) }
                view.onScaleChanged = onScaleChanged
                onViewCreated(view)
            }
        },
        update = { view ->
            view.scene = scene
            view.pickingEnabled = state.tool.needsPicking
        },
    )
}

@Composable
private fun ToolBar(selected: CadTool, enabled: Boolean, onSelect: (CadTool) -> Unit) {
    Surface(tonalElevation = 2.dp) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 8.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            CadTool.entries.forEach { tool ->
                FilterChip(
                    selected = tool == selected,
                    onClick = { onSelect(tool) },
                    enabled = enabled || tool == CadTool.PAN,
                    label = { Text(stringResource(tool.labelRes())) },
                )
            }
        }
    }
}

@Composable
private fun StatusBar(
    state: CadUiState,
    onUnitsChange: (DrawingUnits) -> Unit,
    onPrecisionChange: (Int) -> Unit,
) {
    var showUnits by remember { mutableStateOf(false) }
    var showPrecision by remember { mutableStateOf(false) }

    Surface(tonalElevation = 4.dp) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                modifier = Modifier.weight(1f),
                text = statusMessage(state),
                style = MaterialTheme.typography.bodySmall,
                maxLines = 2,
            )

            Box {
                Text(
                    modifier = Modifier.clickableIf(state.hasDrawing) { showUnits = true },
                    text = unitsLabel(state),
                    style = MaterialTheme.typography.labelLarge,
                )
                DropdownMenu(expanded = showUnits, onDismissRequest = { showUnits = false }) {
                    DrawingUnits.COMMON_METRIC.forEach { units ->
                        DropdownMenuItem(
                            text = { Text(units.abbreviation) },
                            onClick = {
                                showUnits = false
                                onUnitsChange(units)
                            },
                        )
                    }
                }
            }

            Box {
                Text(
                    modifier = Modifier.clickableIf(state.hasDrawing) { showPrecision = true },
                    text = stringResource(R.string.precision_short, state.precision),
                    style = MaterialTheme.typography.labelLarge,
                )
                DropdownMenu(expanded = showPrecision, onDismissRequest = { showPrecision = false }) {
                    (0..3).forEach { decimals ->
                        DropdownMenuItem(
                            text = { Text(decimals.toString()) },
                            onClick = {
                                showPrecision = false
                                onPrecisionChange(decimals)
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyState(onOpen: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(R.string.empty_title),
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            modifier = Modifier
                .padding(top = 8.dp)
                .widthIn(max = 320.dp),
            text = stringResource(R.string.empty_body),
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
        Button(modifier = Modifier.padding(top = 16.dp), onClick = onOpen) {
            Text(stringResource(R.string.open_file))
        }
    }
}

/**
 * Testo della barra di stato: mentre si quota indica il passo successivo, altrimenti riassume
 * cosa si sta guardando. E' anche l'unico posto in cui l'utente scopre che il disegno non
 * dichiara le unita', quindi non resta mai vuoto.
 */
@Composable
private fun statusMessage(state: CadUiState): String {
    val quickMeasure = state.quickMeasure
    return when {
        state.tool.needsPicking && state.remainingPicks > 0 -> {
            val hint = stringResource(state.tool.hintRes(state.pendingPoints.size))
            val snap = state.snapLabel
            if (snap != null) "$hint · $snap" else hint
        }

        quickMeasure != null -> quickMeasure.text(state.formatter)

        state.document.units == DrawingUnits.UNITLESS && state.hasDrawing ->
            stringResource(R.string.status_no_units)

        state.dimensions.isNotEmpty() ->
            stringResource(R.string.status_dimensions, state.dimensions.size)

        else -> stringResource(R.string.status_ready)
    }
}

@Composable
private fun unitsLabel(state: CadUiState): String =
    if (state.document.units == DrawingUnits.UNITLESS) {
        stringResource(R.string.units_unknown)
    } else {
        state.displayUnits.abbreviation
    }

private fun Modifier.clickableIf(enabled: Boolean, onClick: () -> Unit): Modifier =
    if (enabled) this.clickable(onClick = onClick) else this

private fun suggestedName(fileName: String?, extension: String): String {
    val base = fileName?.substringBeforeLast('.')?.takeIf { it.isNotBlank() } ?: "disegno"
    return "$base-quotato.$extension"
}

private fun CadTool.labelRes(): Int = when (this) {
    CadTool.PAN -> R.string.tool_pan
    CadTool.MEASURE -> R.string.tool_measure
    CadTool.LINEAR -> R.string.tool_linear
    CadTool.ALIGNED -> R.string.tool_aligned
    CadTool.ANGULAR -> R.string.tool_angular
    CadTool.RADIUS -> R.string.tool_radius
    CadTool.DIAMETER -> R.string.tool_diameter
    CadTool.ORDINATE -> R.string.tool_ordinate
}

/** Istruzione per il tocco successivo, in base a quanti punti sono gia' stati presi. */
private fun CadTool.hintRes(collected: Int): Int = when (this) {
    CadTool.PAN -> R.string.status_ready
    CadTool.MEASURE -> if (collected == 0) R.string.hint_first_point else R.string.hint_second_point
    CadTool.LINEAR, CadTool.ALIGNED -> when (collected) {
        0 -> R.string.hint_first_point
        1 -> R.string.hint_second_point
        else -> R.string.hint_dim_line
    }

    CadTool.ANGULAR -> when (collected) {
        0 -> R.string.hint_vertex
        1 -> R.string.hint_first_side
        2 -> R.string.hint_second_side
        else -> R.string.hint_arc_position
    }

    CadTool.RADIUS, CadTool.DIAMETER ->
        if (collected == 0) R.string.hint_circle else R.string.hint_leader_direction

    CadTool.ORDINATE -> when (collected) {
        0 -> R.string.hint_origin
        1 -> R.string.hint_feature
        else -> R.string.hint_leader
    }
}

/** Tipi MIME accettati all'apertura: molti file manager marcano i DXF come generici. */
private val OPEN_MIME_TYPES = arrayOf(
    "application/dxf",
    "image/vnd.dxf",
    "application/octet-stream",
    "text/plain",
)
