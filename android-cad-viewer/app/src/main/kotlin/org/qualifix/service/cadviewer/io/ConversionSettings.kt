package org.qualifix.service.cadviewer.io

import android.content.Context

/**
 * Indirizzo e chiave del server di conversione DWG, salvati in locale. Non c'e' un server
 * gestito da Qualifix Service: ognuno ospita il proprio (vedi `server/README.md`), quindi qui
 * si salva solo cio' che l'utente ha configurato.
 */
class ConversionSettings(context: Context) {

    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var serverUrl: String?
        get() = prefs.getString(KEY_SERVER_URL, null)
        set(value) {
            prefs.edit().putString(KEY_SERVER_URL, value?.trim()?.takeIf { it.isNotEmpty() }).apply()
        }

    var apiKey: String?
        get() = prefs.getString(KEY_API_KEY, null)
        set(value) {
            prefs.edit().putString(KEY_API_KEY, value?.trim()?.takeIf { it.isNotEmpty() }).apply()
        }

    val isConfigured: Boolean get() = !serverUrl.isNullOrBlank()

    private companion object {
        const val PREFS_NAME = "dwg_conversion_settings"
        const val KEY_SERVER_URL = "server_url"
        const val KEY_API_KEY = "api_key"
    }
}
