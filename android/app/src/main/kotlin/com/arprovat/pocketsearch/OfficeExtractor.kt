package com.arprovat.pocketsearch

import android.content.Context
import android.net.Uri
import org.apache.poi.hwpf.HWPFDocument
import org.apache.poi.hwpf.extractor.WordExtractor
import org.apache.poi.hslf.usermodel.HSLFSlideShow
import org.apache.poi.hslf.usermodel.HSLFTextParagraph
import org.apache.poi.xslf.usermodel.XMLSlideShow
import org.apache.poi.xwpf.extractor.XWPFWordExtractor
import org.apache.poi.xwpf.usermodel.XWPFDocument

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
                "docx" -> XWPFDocument(stream).use { doc ->
                    XWPFWordExtractor(doc).use { extractor ->
                        doc.bodyElements.mapIndexed { index, element ->
                            val text = StringBuilder()
                            extractor.appendBodyElementText(text, element)
                            mapOf("text" to text.toString(), "section" to "Section ${index + 1}")
                        }
                    }
                }
                "ppt" -> HSLFSlideShow(stream).use { slides ->
                    slides.slides.mapIndexed { index, slide ->
                        mapOf("text" to slide.textParagraphs.joinToString("\n") { HSLFTextParagraph.getText(it) },
                            "slide" to index + 1)
                    }
                }
                "pptx" -> XMLSlideShow(stream).use { slides ->
                    slides.slides.mapIndexed { index, slide ->
                        mapOf("text" to slide.shapes.mapNotNull { shape ->
                            (shape as? org.apache.poi.xslf.usermodel.XSLFTextShape)?.text
                        }.joinToString("\n"), "slide" to index + 1)
                    }
                }
                else -> throw IllegalArgumentException("Unsupported Office format")
            }
        }
    }
}
