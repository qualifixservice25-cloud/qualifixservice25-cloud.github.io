package org.cadviewer.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import org.cadviewer.app.ui.CadScreen
import org.cadviewer.app.ui.CadViewerTheme

class MainActivity : ComponentActivity() {

    private val viewModel: CadViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        openFromIntent(intent)

        setContent {
            val systemDark = isSystemInDarkTheme()
            // Il tema del foglio si puo' staccare da quello di sistema: in cantiere, con il
            // sole in faccia, il fondo scuro e' spesso l'unico leggibile anche di giorno.
            var darkDrawing by remember { mutableStateOf(systemDark) }
            CadViewerTheme(darkTheme = darkDrawing) {
                CadScreen(
                    viewModel = viewModel,
                    darkTheme = darkDrawing,
                    onToggleTheme = { darkDrawing = !darkDrawing },
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        openFromIntent(intent)
    }

    /** Apertura diretta di un .dxf toccato in un gestore file o in un allegato. */
    private fun openFromIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        intent.data?.let(viewModel::open)
    }
}
