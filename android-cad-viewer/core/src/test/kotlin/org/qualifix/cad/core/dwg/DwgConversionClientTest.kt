package org.qualifix.cad.core.dwg

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpHandler
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * Il client parla con un server vero (com.sun.net.httpserver, incluso nel JDK): cosi' si
 * verificano davvero i byte che vanno sul filo, non solo un mock dell'interfaccia HTTP.
 */
class DwgConversionClientTest {

    private lateinit var server: HttpServer

    @AfterTest
    fun stopServer() {
        if (::server.isInitialized) server.stop(0)
    }

    private fun startServer(handler: HttpHandler): String {
        server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/v1/convert", handler)
        server.start()
        return "http://127.0.0.1:${server.address.port}"
    }

    @Test
    fun `una conversione riuscita restituisce i byte del DXF`() {
        val fakeDxf = "0\nSECTION\n0\nEOF\n".toByteArray(StandardCharsets.UTF_8)
        val url = startServer { exchange ->
            exchange.responseHeaders.add("Content-Type", "application/dxf")
            exchange.sendResponseHeaders(200, fakeDxf.size.toLong())
            exchange.responseBody.use { it.write(fakeDxf) }
        }

        val client = DwgConversionClient(serverUrl = url)
        val result = client.convert("contenuto finto del dwg".toByteArray(), "muro.dwg")

        assertEquals(fakeDxf.toList(), result.toList())
    }

    @Test
    fun `il corpo inviato e' un multipart valido con il file allegato`() {
        var received: ByteArray? = null
        var receivedContentType: String? = null
        val url = startServer { exchange ->
            receivedContentType = exchange.requestHeaders.getFirst("Content-Type")
            received = exchange.requestBody.use { it.readBytes() }
            exchange.sendResponseHeaders(200, 3)
            exchange.responseBody.use { it.write(byteArrayOf(1, 2, 3)) }
        }

        DwgConversionClient(serverUrl = url).convert(byteArrayOf(0x41, 0x43, 0x31, 0x30), "pianta.dwg")

        val bodyText = String(received!!, StandardCharsets.ISO_8859_1)
        assertTrue(receivedContentType!!.startsWith("multipart/form-data; boundary="))
        assertTrue(bodyText.contains("name=\"file\""))
        assertTrue(bodyText.contains("filename=\"pianta.dwg\""))
        assertTrue(bodyText.contains("Content-Type: application/octet-stream"))
        // I byte del "dwg" devono comparire cosi' come sono, non incapsulati in testo.
        assertTrue(bodyText.contains("AC10"))
    }

    @Test
    fun `l'intestazione X-Api-Key arriva solo se e' stata configurata`() {
        var apiKeyHeader: String? = null
        val url = startServer { exchange ->
            apiKeyHeader = exchange.requestHeaders.getFirst("X-Api-Key")
            exchange.requestBody.use { it.readBytes() }
            exchange.sendResponseHeaders(200, 1)
            exchange.responseBody.use { it.write(byteArrayOf(0)) }
        }

        DwgConversionClient(serverUrl = url, apiKey = "segreto-123").convert(byteArrayOf(1), "a.dwg")

        assertEquals("segreto-123", apiKeyHeader)
    }

    @Test
    fun `senza indirizzo server la conversione non parte nemmeno`() {
        assertFailsWith<DwgConversionException.NotConfigured> {
            DwgConversionClient(serverUrl = null).convert(byteArrayOf(1), "a.dwg")
        }
        assertFailsWith<DwgConversionException.NotConfigured> {
            DwgConversionClient(serverUrl = "   ").convert(byteArrayOf(1), "a.dwg")
        }
    }

    @Test
    fun `un 422 con codice CONVERSION_FAILED diventa un Rejected leggibile`() {
        val url = startServer { exchange ->
            exchange.requestBody.use { it.readBytes() }
            val body = "CONVERSION_FAILED\nIl file DWG sembra danneggiato".toByteArray(StandardCharsets.UTF_8)
            exchange.responseHeaders.add("Content-Type", "text/plain")
            exchange.sendResponseHeaders(422, body.size.toLong())
            exchange.responseBody.use { it.write(body) }
        }

        val error = assertFailsWith<DwgConversionException.Rejected> {
            DwgConversionClient(serverUrl = url).convert(byteArrayOf(1), "a.dwg")
        }
        assertEquals("CONVERSION_FAILED", error.code)
        assertEquals("Il file DWG sembra danneggiato", error.detail)
    }

    @Test
    fun `un 500 diventa un ServerError con lo status originale`() {
        val url = startServer { exchange ->
            exchange.requestBody.use { it.readBytes() }
            val body = "INTERNAL\nConvertitore non configurato sul server".toByteArray(StandardCharsets.UTF_8)
            exchange.sendResponseHeaders(500, body.size.toLong())
            exchange.responseBody.use { it.write(body) }
        }

        val error = assertFailsWith<DwgConversionException.ServerError> {
            DwgConversionClient(serverUrl = url).convert(byteArrayOf(1), "a.dwg")
        }
        assertEquals(500, error.status)
        assertTrue(error.message!!.contains("Convertitore non configurato"))
    }

    @Test
    fun `un corpo di errore vuoto non manda in eccezione il parsing`() {
        val url = startServer { exchange ->
            exchange.requestBody.use { it.readBytes() }
            exchange.sendResponseHeaders(503, -1)
            exchange.responseBody.close()
        }

        val error = assertFailsWith<DwgConversionException.ServerError> {
            DwgConversionClient(serverUrl = url).convert(byteArrayOf(1), "a.dwg")
        }
        assertEquals(503, error.status)
    }

    @Test
    fun `un indirizzo non raggiungibile diventa un errore di rete`() {
        // Porta chiusa in locale: nessun server in ascolto, la connessione viene rifiutata subito.
        val client = DwgConversionClient(serverUrl = "http://127.0.0.1:1", connectTimeoutMs = 500)
        assertFailsWith<DwgConversionException.Network> {
            client.convert(byteArrayOf(1), "a.dwg")
        }
    }

    @Test
    fun `un nome file con virgolette non rompe l'header multipart`() {
        var received: String? = null
        val url = startServer { exchange ->
            received = exchange.requestBody.use { it.readBytes() }.toString(StandardCharsets.ISO_8859_1)
            exchange.sendResponseHeaders(200, 1)
            exchange.responseBody.use { it.write(byteArrayOf(0)) }
        }

        DwgConversionClient(serverUrl = url).convert(byteArrayOf(1), "muro \"esterno\".dwg")

        assertTrue(received!!.contains("filename=\"muro 'esterno'.dwg\""))
    }
}
