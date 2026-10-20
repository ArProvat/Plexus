package com.arprovat.pocketsearch

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.rendering.ImageType
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.util.concurrent.TimeUnit

class PdfExtractor(private val context: Context) {
    init {
        PDFBoxResourceLoader.init(context)
    }

    private var currentUri: Uri? = null
    private var currentDocument: PDDocument? = null
    private var pfd: ParcelFileDescriptor? = null
    private var nativeRenderer: android.graphics.pdf.PdfRenderer? = null
    private var pdfboxRenderer: com.tom_roush.pdfbox.rendering.PDFRenderer? = null
    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    private fun document(uri: Uri): PDDocument {
        if (uri == currentUri && currentDocument != null) return currentDocument!!
        close()
        val stream = context.contentResolver.openInputStream(uri)
            ?: throw SecurityException("Cannot open selected PDF")
        currentDocument = try {
            stream.use { input ->
                PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
            }
        } catch (_: InvalidPasswordException) {
            throw IllegalArgumentException("Password-protected PDF requires a password")
        }
        currentUri = uri
        return currentDocument!!
    }

    fun pageCount(uri: Uri): Int = document(uri).numberOfPages

    fun page(uri: Uri, number: Int): String {
        val pdf = document(uri)
        require(number in 1..pdf.numberOfPages) { "Invalid PDF page: $number" }

        // Step 1: Direct digital text layer extraction (Fast & Clean)
        val directText = PDFTextStripper().apply {
            startPage = number
            endPage = number
        }.getText(pdf).trim()

        if (directText.isNotBlank()) {
            return directText
        }

        // Step 2: Fallback to 300 DPI rasterization + on-device OCR
        val pageIndex = number - 1
        var bitmap: Bitmap? = null
        return try {
            bitmap = renderPageNative(uri, pageIndex) ?: renderPagePdfBox(pageIndex)
            runOcr(bitmap)
        } catch (_: Exception) {
            ""
        } finally {
            bitmap?.recycle()
        }
    }

    private fun renderPageNative(uri: Uri, pageIndex: Int): Bitmap? {
        val descriptor = pfd ?: try {
            context.contentResolver.openFileDescriptor(uri, "r")?.also { pfd = it }
        } catch (_: Exception) {
            null
        } ?: return null

        val renderer = nativeRenderer ?: try {
            android.graphics.pdf.PdfRenderer(descriptor).also { nativeRenderer = it }
        } catch (_: Exception) {
            return null
        }

        return try {
            val page = renderer.openPage(pageIndex)
            try {
                // Standard PDF point = 1/72 inch; 300 DPI scale = 300 / 72 ≈ 4.1667
                val scale = 300f / 72f
                val width = (page.width * scale).toInt()
                val height = (page.height * scale).toInt()
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                canvas.drawColor(Color.WHITE)
                page.render(bitmap, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                bitmap
            } finally {
                page.close()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun renderPagePdfBox(pageIndex: Int): Bitmap {
        val doc = currentDocument ?: throw IllegalStateException("Document not opened")
        val boxRenderer = pdfboxRenderer ?: com.tom_roush.pdfbox.rendering.PDFRenderer(doc).also {
            pdfboxRenderer = it
        }
        return boxRenderer.renderImageWithDPI(pageIndex, 300f, ImageType.RGB)
    }

    private fun runOcr(bitmap: Bitmap): String {
        val image = InputImage.fromBitmap(bitmap, 0)
        val visionText = Tasks.await(textRecognizer.process(image), 30, TimeUnit.SECONDS)
        return visionText.text.trim()
    }

    fun close() {
        try {
            nativeRenderer?.close()
        } catch (_: Exception) {}
        nativeRenderer = null

        try {
            pfd?.close()
        } catch (_: Exception) {}
        pfd = null

        pdfboxRenderer = null

        try {
            currentDocument?.close()
        } catch (_: Exception) {}
        currentDocument = null

        currentUri = null
    }

    fun destroy() {
        close()
        try {
            textRecognizer.close()
        } catch (_: Exception) {}
    }
}
