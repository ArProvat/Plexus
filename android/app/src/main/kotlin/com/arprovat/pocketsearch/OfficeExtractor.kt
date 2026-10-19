package com.arprovat.pocketsearch

import android.content.Context
import android.net.Uri
import android.util.Xml
import org.apache.poi.hslf.usermodel.HSLFSlideShow
import org.apache.poi.hslf.usermodel.HSLFTextParagraph
import org.apache.poi.hwpf.HWPFDocument
import org.apache.poi.hwpf.extractor.WordExtractor
import org.xmlpull.v1.XmlPullParser
import java.util.zip.ZipInputStream

class OfficeExtractor(private val context: Context) {
    fun extract(uri: Uri, name: String): List<Map<String, Any?>> {
        val extension = name.substringAfterLast('.').lowercase()
        val input = context.contentResolver.openInputStream(uri)
            ?: throw SecurityException("Cannot open selected document")
        input.use { stream ->
            return when (extension) {
                "doc" -> HWPFDocument(stream).use { doc ->
                    WordExtractor(doc).use { extractor ->
                        extractor.paragraphText.mapIndexed { index, text ->
                            mapOf("text" to text, "section" to "Paragraph ${index + 1}")
                        }
                    }
                }
                "ppt" -> HSLFSlideShow(stream).use { slides ->
                    slides.slides.mapIndexed { index, slide ->
                        mapOf("text" to slide.textParagraphs.joinToString("\n") {
                            HSLFTextParagraph.getText(it)
                        }, "slide" to index + 1)
                    }
                }
                "docx" -> readDocx(ZipInputStream(stream))
                "pptx" -> readPptx(ZipInputStream(stream))
                else -> throw IllegalArgumentException("Unsupported Office format")
            }
        }
    }

    private fun readDocx(zip: ZipInputStream): List<Map<String, Any?>> {
        zip.use { archive ->
            while (true) {
                val entry = archive.nextEntry ?: break
                if (entry.name == "word/document.xml") {
                    val paragraphs = parseParagraphs(archive, "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
                    return paragraphs.mapIndexed { index, text ->
                        mapOf("text" to text, "section" to "Paragraph ${index + 1}")
                    }
                }
                archive.closeEntry()
            }
        }
        throw IllegalArgumentException("DOCX has no main document text")
    }

    private fun readPptx(zip: ZipInputStream): List<Map<String, Any?>> {
        val slides = mutableListOf<Pair<Int, String>>()
        val slideName = Regex("ppt/slides/slide([0-9]+)\\.xml")
        zip.use { archive ->
            while (true) {
                val entry = archive.nextEntry ?: break
                val number = slideName.matchEntire(entry.name)?.groupValues?.get(1)?.toIntOrNull()
                if (number != null) {
                    val paragraphs = parseParagraphs(archive, "http://schemas.openxmlformats.org/drawingml/2006/main")
                    slides.add(number to paragraphs.joinToString("\n"))
                }
                archive.closeEntry()
            }
        }
        if (slides.isEmpty()) throw IllegalArgumentException("PPTX has no slides")
        return slides.sortedBy { it.first }.map { (number, text) ->
            mapOf("text" to text, "slide" to number)
        }
    }

    private fun parseParagraphs(input: java.io.InputStream, namespace: String): List<String> {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, true)
        parser.setInput(input, "UTF-8")
        val paragraphs = mutableListOf<String>()
        var current: StringBuilder? = null
        while (parser.eventType != XmlPullParser.END_DOCUMENT) {
            if (parser.namespace == namespace) {
                when (parser.eventType) {
                    XmlPullParser.START_TAG -> when (parser.name) {
                        "p" -> current = StringBuilder()
                        "t" -> if (current != null) current.append(parser.nextText())
                        "tab" -> current?.append('\t')
                        "br" -> current?.append('\n')
                    }
                    XmlPullParser.END_TAG -> if (parser.name == "p" && current != null) {
                        paragraphs.add(current.toString())
                        current = null
                    }
                }
            }
            parser.next()
        }
        return paragraphs
    }
}
