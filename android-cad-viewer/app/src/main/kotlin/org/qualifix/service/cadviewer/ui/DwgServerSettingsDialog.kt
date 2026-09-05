package org.qualifix.service.cadviewer.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import org.qualifix.service.cadviewer.R

/**
 * Indirizzo e chiave del server di conversione DWG (vedi `server/README.md`): non c'e' un
 * server gestito da Qualifix Service, quindi qui l'utente configura il proprio.
 */
@Composable
fun DwgServerSettingsDialog(
    currentServerUrl: String?,
    currentApiKey: String?,
    onSave: (serverUrl: String?, apiKey: String?) -> Unit,
    onDismiss: () -> Unit,
) {
    var serverUrl by remember { mutableStateOf(currentServerUrl.orEmpty()) }
    var apiKey by remember { mutableStateOf(currentApiKey.orEmpty()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.dwg_settings_title)) },
        text = {
            Column {
                Text(
                    text = stringResource(R.string.dwg_settings_body),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(bottom = 12.dp),
                )
                OutlinedTextField(
                    value = serverUrl,
                    onValueChange = { serverUrl = it },
                    label = { Text(stringResource(R.string.dwg_settings_server_url)) },
                    placeholder = { Text("https://cad.tuodominio.it") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = apiKey,
                    onValueChange = { apiKey = it },
                    label = { Text(stringResource(R.string.dwg_settings_api_key)) },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                onSave(serverUrl, apiKey)
                onDismiss()
            }) {
                Text(stringResource(R.string.action_save))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_cancel))
            }
        },
    )
}
