package com.arprovat.pocketsearch

import android.content.Context
import android.net.Uri
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper

class PdfExtractor(private val context: Context) {
    init { PDFBoxResourceLoader.init(context) }
    private var currentUri: Uri? = null
    private var currentDocument: PDDocument? = null

    private fun document(uri: Uri): PDDocument {
        if (uri == currentUri && currentDocument != null) return currentDocument!!
        close()
        val stream = context.contentResolver.openInputStream(uri)
            ?: throw SecurityException("Cannot open selected PDF")
        currentDocument = stream.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
        }
        currentUri = uri
        return currentDocument!!
    }

    fun pageCount(uri: Uri): Int = document(uri).numberOfPages

    fun page(uri: Uri, number: Int): String {
        val pdf = document(uri)
        require(number in 1..pdf.numberOfPages) { "Invalid PDF page" }
        return PDFTextStripper().apply { startPage = number; endPage = number }.getText(pdf)
    }

    fun close() { currentDocument?.close(); currentDocument = null; currentUri = null }
}
