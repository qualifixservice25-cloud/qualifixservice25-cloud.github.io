package org.cadviewer.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import org.cadviewer.app.R
import org.cadviewer.core.model.AciPalette
import org.cadviewer.core.model.CadLayer

/**
 * Pannello dei layer. Riproduce l'organizzazione del disegno originale: spegnere i layer e'
 * spesso l'unico modo di leggere una pianta densa su uno schermo da sei pollici.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LayersSheet(
    layers: List<CadLayer>,
    hiddenLayers: Set<String>,
    onToggle: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            Text(
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                text = stringResource(R.string.layers_title, layers.size),
                style = MaterialTheme.typography.titleMedium,
            )

            if (layers.isEmpty()) {
                Text(
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 16.dp),
                    text = stringResource(R.string.layers_empty),
                    style = MaterialTheme.typography.bodyMedium,
                )
                return@Column
            }

            LazyColumn {
                items(layers, key = { it.name }) { layer ->
                    LayerRow(
                        layer = layer,
                        visible = layer.name !in hiddenLayers,
                        onToggle = { onToggle(layer.name) },
                    )
                }
            }
        }
    }
}

@Composable
private fun LayerRow(layer: CadLayer, visible: Boolean, onToggle: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(horizontal = 24.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Pastiglia con il colore ACI del layer: e' il riferimento che l'utente ha in mente
        // guardando la tavola nel CAD desktop.
        Box(
            modifier = Modifier
                .size(16.dp)
                .clip(CircleShape)
                .background(Color(AciPalette.rgb(layer.color.index) or ALPHA_OPAQUE)),
        )

        Column(modifier = Modifier.weight(1f)) {
            Text(text = layer.name, style = MaterialTheme.typography.bodyLarge)
            if (layer.locked) {
                Text(
                    text = stringResource(R.string.layer_locked),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }

        Switch(checked = visible, onCheckedChange = { onToggle() })
    }
}

private const val ALPHA_OPAQUE = 0xFF shl 24
