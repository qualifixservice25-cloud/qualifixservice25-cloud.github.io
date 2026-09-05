package org.qualifix.service.cadviewer.io

import android.content.ContentResolver
import android.content.Context
import android.graphics.Canvas
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import org.qualifix.cad.core.dimension.Dimension
import org.qualifix.cad.core.dwg.DwgConversionClient
import org.qualifix.cad.core.dxf.DxfParser
import org.qualifix.cad.core.dxf.DxfWriter
import org.qualifix.cad.core.measure.MeasurementFormatter
import org.qualifix.cad.core.model.CadDocument
import org.qualifix.service.cadviewer.render.CadRenderer
import org.qualifix.service.cadviewer.render.Viewport
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/** Documento appena caricato, con il nome del file da mostrare in barra. */
data class LoadedDrawing(val fileName: String, val document: CadDocument)

/**
 * Lettura e scrittura dei file, tutta attraverso lo Storage Access Framework: l'app non chiede
 * mai il permesso di leggere l'archivio, riceve solo il singolo documento che l'utente sceglie.
 */
object DrawingRepository {

    fun load(context: Context, uri: Uri, conversionSettings: ConversionSettings): LoadedDrawing {
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: error("Impossibile aprire il file selezionato")
        val name = displayName(context, uri)

        val dxfBytes = if (looksLikeDwg(name, bytes)) {
            val client = DwgConversionClient(
                serverUrl = conversionSettings.serverUrl,
                apiKey = conversionSettings.apiKey,
            )
            client.convert(bytes, name)
        } else {
            bytes
        }

        return LoadedDrawing(name, DxfParser.parse(decode(dxfBytes)))
    }

    /**
     * L'estensione basta quasi sempre, ma alcuni file provider di app cloud restituiscono nomi
     * senza estensione: in quel caso si guarda la sigla di versione con cui inizia ogni DWG
     * binario (es. "AC1027" per AutoCAD 2013-2017), cosi' un DWG rinominato o senza estensione
     * non finisce comunque nel parser DXF, che lo rifiuterebbe con un errore poco chiaro.
     */
    internal fun looksLikeDwg(name: String, bytes: ByteArray): Boolean {
        if (name.substringAfterLast('.', "").equals("dwg", ignoreCase = true)) return true
        if (bytes.size < 6 || bytes[0] != 'A'.code.toByte() || bytes[1] != 'C'.code.toByte()) return false
        return (2..5).all { bytes[it].toInt().toChar().isDigit() }
    }

    /**
     * I DXF italiani girano in due codifiche: quelli esportati da AutoCAD su Windows sono in
     * CP1252 (Latin-1), quelli piu' recenti in UTF-8. Si prova UTF-8 in modo rigoroso e si
     * ripiega su Latin-1, che non fallisce mai: cosi' un nome di layer con l'accento non
     * manda in errore il caricamento.
     */
    internal fun decode(bytes: ByteArray): String = try {
        StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(java.nio.ByteBuffer.wrap(bytes))
            .toString()
    } catch (_: CharacterCodingException) {
        String(bytes, StandardCharsets.ISO_8859_1)
    }

    fun exportDxf(
        resolver: ContentResolver,
        uri: Uri,
        document: CadDocument,
        dimensions: List<Dimension>,
        formatter: MeasurementFormatter,
    ) {
        val content = DxfWriter.write(document, dimensions, formatter)
        resolver.openOutputStream(uri, "wt")?.use { output ->
            output.write(content.toByteArray(StandardCharsets.UTF_8))
        } ?: error("Impossibile scrivere il file di destinazione")
    }

    /**
     * Stampa del disegno con le quote su una pagina A4 orizzontale. Serve a mandare per email
     * o WhatsApp quello che si e' misurato, che e' quasi sempre il passo successivo al rilievo.
     */
    fun exportPdf(
        resolver: ContentResolver,
        uri: Uri,
        document: CadDocument,
        dimensions: List<Dimension>,
        formatter: MeasurementFormatter,
        hiddenLayers: Set<String> = emptySet(),
    ) {
        val pdf = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(A4_LANDSCAPE_WIDTH_PT, A4_LANDSCAPE_HEIGHT_PT, 1).create()
        val page = pdf.startPage(pageInfo)
        try {
            drawPage(page.canvas, document, dimensions, formatter, hiddenLayers)
        } finally {
            pdf.finishPage(page)
        }
        resolver.openOutputStream(uri, "wt")?.use { pdf.writeTo(it) }
            ?: error("Impossibile scrivere il PDF di destinazione")
        pdf.close()
    }

    private fun drawPage(
        canvas: Canvas,
        document: CadDocument,
        dimensions: List<Dimension>,
        formatter: MeasurementFormatter,
        hiddenLayers: Set<String>,
    ) {
        val entities = document.flattenedEntities()
            .filter { it.layer !in hiddenLayers }
        val viewport = Viewport().apply {
            setViewSize(A4_LANDSCAPE_WIDTH_PT, A4_LANDSCAPE_HEIGHT_PT)
            fit(document.bounds, paddingFraction = 0.05)
        }
        // Su carta si stampa in nero su bianco, non con il fondo scuro della vista di cantiere.
        val renderer = CadRenderer().apply { darkBackground = false }
        renderer.drawScene(
            canvas = canvas,
            viewport = viewport,
            entities = entities,
            layers = document.layers.associateBy { it.name },
            dimensions = dimensions.map { it.geometry(formatter) },
            lineWidthPx = 1f,
        )
    }

    internal fun displayName(context: Context, uri: Uri): String =
        DocumentFile.fromSingleUri(context, uri)?.name
            ?: uri.lastPathSegment?.substringAfterLast('/')
            ?: "disegno.dxf"

    /** A4 orizzontale a 72 dpi, l'unita' con cui lavora PdfDocument. */
    private const val A4_LANDSCAPE_WIDTH_PT = 842
    private const val A4_LANDSCAPE_HEIGHT_PT = 595
}
