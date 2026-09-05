package org.qualifix.cad.core.dwg

import java.io.IOException
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.UUID

/**
 * Motivo per cui una conversione DWG -> DXF non ha prodotto un file. Distinto per messaggio
 * all'utente: "non hai configurato un server" e "il server ha rifiutato il file" richiedono
 * azioni completamente diverse da parte sua.
 */
sealed class DwgConversionException(message: String, cause: Throwable? = null) : Exception(message, cause) {

    /** Nessun indirizzo server salvato nelle impostazioni: non e' un errore di rete. */
    class NotConfigured :
        DwgConversionException("Nessun server di conversione configurato nelle impostazioni")

    /** Connessione, DNS, timeout: il server potrebbe anche essere raggiungibile in altre condizioni. */
    class Network(message: String, cause: Throwable? = null) : DwgConversionException(message, cause)

    /**
     * Il server ha risposto ma la conversione non e' riuscita (es. DWG binario corrotto, versione
     * non supportata dal convertitore installato sul server). [code] e' il codice macchina della
     * risposta, utile nei log; [detail] e' il messaggio in chiaro da mostrare.
     */
    class Rejected(val code: String, val detail: String) : DwgConversionException(detail)

    /** Risposta HTTP inattesa (5xx, corpo malformato): probabile problema di configurazione server. */
    class ServerError(val status: Int, message: String) : DwgConversionException(message)
}

/**
 * Carica un DWG su un server di conversione self-hosted (vedi `server/` nel repository, un
 * wrapper attorno a ODA File Converter) e restituisce il DXF prodotto.
 *
 * Il protocollo e' deliberatamente minimo, per non tirare dentro una libreria HTTP ne' un parser
 * JSON su un modulo che deve restare Kotlin puro:
 * - richiesta: `POST {serverUrl}/v1/convert`, corpo multipart/form-data con un solo campo `file`;
 *   intestazione `X-Api-Key` se [apiKey] non e' nullo.
 * - risposta 200: corpo binario, il DXF convertito.
 * - risposta di errore: `Content-Type: text/plain`, prima riga = codice macchina, resto = messaggio
 *   per l'utente (vedi `server/app.py::_write_error`).
 */
class DwgConversionClient(
    private val serverUrl: String?,
    private val apiKey: String? = null,
    private val connectTimeoutMs: Int = 10_000,
    /** Un DWG di cantiere pesante puo' richiedere piu' di un minuto sul lato server. */
    private val readTimeoutMs: Int = 90_000,
) {

    fun convert(dwgBytes: ByteArray, fileName: String): ByteArray {
        val base = serverUrl?.trim()?.takeIf { it.isNotEmpty() } ?: throw DwgConversionException.NotConfigured()
        val endpoint = base.trimEnd('/') + "/v1/convert"
        val boundary = "----qualifix-cad-${UUID.randomUUID()}"

        val connection = try {
            (URI(endpoint).toURL().openConnection() as HttpURLConnection)
        } catch (e: Exception) {
            throw DwgConversionException.Network("Indirizzo server non valido: ${e.message}", e)
        }

        return try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = connectTimeoutMs
            connection.readTimeout = readTimeoutMs
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
            apiKey?.takeIf { it.isNotBlank() }?.let { connection.setRequestProperty("X-Api-Key", it) }

            connection.outputStream.use { output ->
                writeMultipartBody(output, boundary, fileName, dwgBytes)
            }

            val status = connection.responseCode
            if (status == HttpURLConnection.HTTP_OK) {
                connection.inputStream.use { it.readBytes() }
            } else {
                // Con un errore senza corpo (es. 503 -1) errorStream e' null: non bisogna
                // ripiegare su inputStream, che su uno status >= 400 rilancia la stessa IOException
                // che HttpURLConnection ha gia' usato per segnalare l'errore.
                val body = connection.errorStream?.use { it.readBytes() } ?: ByteArray(0)
                throw parseErrorResponse(status, body)
            }
        } catch (e: DwgConversionException) {
            throw e
        } catch (e: SocketTimeoutException) {
            throw DwgConversionException.Network("Il server non ha risposto in tempo", e)
        } catch (e: IOException) {
            throw DwgConversionException.Network("Impossibile contattare il server: ${e.message}", e)
        } finally {
            connection.disconnect()
        }
    }

    /**
     * Corpo `text/plain`: prima riga codice macchina (es. CONVERSION_FAILED), righe successive il
     * messaggio. Un corpo vuoto o senza quella forma diventa un ServerError generico invece di
     * far esplodere il parsing.
     */
    private fun parseErrorResponse(status: Int, body: ByteArray): DwgConversionException {
        val text = String(body, StandardCharsets.UTF_8).trim()
        if (text.isEmpty()) {
            return DwgConversionException.ServerError(status, "Il server ha risposto con codice $status")
        }
        val lines = text.split('\n', limit = 2)
        val code = lines[0].trim()
        val detail = lines.getOrElse(1) { "" }.trim().ifEmpty { code }
        return if (status == 422) {
            DwgConversionException.Rejected(code, detail)
        } else {
            DwgConversionException.ServerError(status, detail)
        }
    }

    private fun writeMultipartBody(output: OutputStream, boundary: String, fileName: String, bytes: ByteArray) {
        val safeName = fileName.substringAfterLast('/').substringAfterLast('\\').ifBlank { "disegno.dwg" }
        val header = buildString {
            append("--").append(boundary).append("\r\n")
            append("Content-Disposition: form-data; name=\"file\"; filename=\"").append(escapeQuotes(safeName)).append("\"\r\n")
            append("Content-Type: application/octet-stream\r\n")
            append("\r\n")
        }
        val footer = "\r\n--$boundary--\r\n"

        output.write(header.toByteArray(StandardCharsets.UTF_8))
        output.write(bytes)
        output.write(footer.toByteArray(StandardCharsets.UTF_8))
    }

    private fun escapeQuotes(value: String): String = value.replace("\"", "'")
}
