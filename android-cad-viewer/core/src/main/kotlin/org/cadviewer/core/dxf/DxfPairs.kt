package org.cadviewer.core.dxf

import java.io.BufferedReader
import java.io.Reader

/** Coppia group code / valore: l'unita' atomica di un file DXF ASCII. */
data class DxfPair(val code: Int, val value: String) {
    fun asDouble(): Double? = value.trim().toDoubleOrNull()
    fun asInt(): Int? = value.trim().toDoubleOrNull()?.toInt()
}

class DxfFormatException(message: String) : Exception(message)

/**
 * Lettura di un DXF ASCII come sequenza di coppie.
 *
 * Il formato alterna una riga con il group code e una con il valore. Le righe possono avere
 * spazi in testa (i file scritti a mano o passati per convertitori li aggiungono) e il valore
 * puo' essere vuoto, quindi non si puo' fare trim del valore in modo cieco: i codici di testo
 * (1, 3, 7, 2...) devono conservare gli spazi interni.
 */
object DxfPairReader {

    private const val BINARY_SENTINEL = "AutoCAD Binary DXF"

    fun read(reader: Reader): List<DxfPair> {
        val buffered = reader as? BufferedReader ?: BufferedReader(reader)
        val pairs = mutableListOf<DxfPair>()
        var lineNumber = 0

        while (true) {
            val codeLine = buffered.readLine() ?: break
            lineNumber++
            if (lineNumber == 1 && codeLine.startsWith(BINARY_SENTINEL)) {
                throw DxfFormatException(
                    "File in formato DXF binario: convertirlo in DXF ASCII prima di aprirlo.",
                )
            }
            val trimmedCode = codeLine.trim()
            if (trimmedCode.isEmpty()) continue

            val code = trimmedCode.toIntOrNull()
                ?: throw DxfFormatException("Group code non valido alla riga $lineNumber: \"$codeLine\"")

            val valueLine = buffered.readLine()
                ?: throw DxfFormatException("File troncato: manca il valore del group code $code")
            lineNumber++

            pairs += DxfPair(code, valueLine.trimEnd('\r', '\n'))
        }
        return pairs
    }

    fun read(text: String): List<DxfPair> = read(text.reader())
}

/**
 * Un record DXF: il tipo (valore del group code 0) e tutte le coppie che lo seguono fino al
 * record successivo. L'ordine viene conservato perche' alcune entita' (LWPOLYLINE su tutte)
 * lo usano per legare un bulge al vertice che lo precede.
 */
class DxfRecord(val type: String, val pairs: List<DxfPair>) {

    fun string(code: Int): String? = pairs.firstOrNull { it.code == code }?.value

    fun double(code: Int): Double? = pairs.firstOrNull { it.code == code }?.asDouble()

    fun double(code: Int, default: Double): Double = double(code) ?: default

    fun int(code: Int): Int? = pairs.firstOrNull { it.code == code }?.asInt()

    fun int(code: Int, default: Int): Int = int(code) ?: default

    fun allStrings(code: Int): List<String> = pairs.filter { it.code == code }.map { it.value }

    fun has(code: Int): Boolean = pairs.any { it.code == code }

    override fun toString(): String = "DxfRecord($type, ${pairs.size} coppie)"
}
