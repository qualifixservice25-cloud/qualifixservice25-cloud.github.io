package org.qualifix.service.cadviewer.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Tavolozza dell'interfaccia, tenuta volutamente sobria: il colore che conta e' quello del
 * disegno e delle quote, e ogni tinta forte nella cornice ruberebbe attenzione al tratto.
 */
private val CadTeal = Color(0xFF0E7C86)
private val CadTealLight = Color(0xFF58E0D6)
private val QuoteAmber = Color(0xFFB5651D)
private val QuoteAmberLight = Color(0xFFE0954F)

private val LightColors = lightColorScheme(
    primary = CadTeal,
    secondary = QuoteAmber,
    background = Color(0xFFFAFAF8),
    surface = Color(0xFFF2F3F1),
)

private val DarkColors = darkColorScheme(
    primary = CadTealLight,
    secondary = QuoteAmberLight,
    background = Color(0xFF101418),
    surface = Color(0xFF16202A),
)

@Composable
fun CadViewerTheme(darkTheme: Boolean, content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
