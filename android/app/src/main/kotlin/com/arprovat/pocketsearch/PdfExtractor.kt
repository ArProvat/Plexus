package com.arprovat.pocketsearch

import android.content.Context
import android.net.Uri
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper

class PdfExtractor(private val context: Context) {
    init { PDFBoxResourceLoader.init(context) }

    private fun <T> withDocument(uri: Uri, operation: (PDDocument) -> T): T {
        val stream = context.contentResolver.openInputStream(uri)
            ?: throw SecurityException("Cannot open selected PDF")
        stream.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use(operation)
        }
    }

    fun pageCount(uri: Uri): Int = withDocument(uri) { it.numberOfPages }

    fun page(uri: Uri, number: Int): String = withDocument(uri) { document ->
        require(number in 1..document.numberOfPages) { "Invalid PDF page" }
        PDFTextStripper().apply { startPage = number; endPage = number }.getText(document)
    }
}
