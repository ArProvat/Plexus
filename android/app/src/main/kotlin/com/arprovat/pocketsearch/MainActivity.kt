package com.arprovat.pocketsearch

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var embedder: EmbeddingEngine
    private lateinit var documents: DocumentAccess
    private lateinit var pdfs: PdfExtractor
    private lateinit var office: OfficeExtractor
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        embedder = EmbeddingEngine(applicationContext)
        documents = DocumentAccess(this)
        pdfs = PdfExtractor(applicationContext)
        office = OfficeExtractor(applicationContext)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.arprovat.pocketsearch/native")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method == "consumeSearchLaunch") {
                result.success(intent.action == SEARCH_ACTION)
                intent.action = Intent.ACTION_MAIN
            } else if (call.method == "pickFiles") {
                documents.pickFiles(result)
            } else if (call.method == "pickFolder") {
                documents.pickFolder(result)
            } else if (call.method in setOf("initializeEmbedding", "embedQuery", "embedDocuments",
                    "disposeEmbedding", "downloadModel", "modelStatus", "listFolder", "readText",
                    "pdfPageCount", "extractPdfPage", "closePdf", "extractOffice", "openSource")) {
                worker.execute {
                    try {
                        val value: Any? = when (call.method) {
                            "initializeEmbedding" -> embedder.initialize()
                            "modelStatus" -> embedder.status()
                            "downloadModel" -> { embedder.download(); null }
                            "embedQuery" -> embedder.embed(call.arguments as? String
                                ?: throw IllegalArgumentException("Expected query text"))
                            "embedDocuments" -> {
                                val texts = call.arguments as? List<*>
                                    ?: throw IllegalArgumentException("Expected passages")
                                require(texts.size in 1..8) { "Batch size must be 1-8" }
                                texts.map {
                                    val value = it as? String
                                        ?: throw IllegalArgumentException("Expected text")
                                    val title = value.substringBefore('\n')
                                    embedder.embed(value.substringAfter('\n', value),
                                        document = true, title = title)
                                }
                            }
                            "listFolder" -> documents.listFolder(android.net.Uri.parse(call.arguments as String))
                            "readText" -> documents.readText(android.net.Uri.parse(call.arguments as String))
                            "pdfPageCount" -> pdfs.pageCount(android.net.Uri.parse(call.arguments as String))
                            "closePdf" -> { pdfs.close(); null }
                            "extractPdfPage" -> {
                                val args = call.arguments as Map<*, *>
                                pdfs.page(android.net.Uri.parse(args["uri"] as String), args["page"] as Int)
                            }
                            "extractOffice" -> {
                                val args = call.arguments as Map<*, *>
                                office.extract(android.net.Uri.parse(args["uri"] as String), args["name"] as String)
                            }
                            "openSource" -> { main.post { try {
                                documents.openSource(android.net.Uri.parse(call.arguments as String))
                                result.success(null)
                            } catch (e: Exception) { result.error("OPEN_ERROR", e.message, null) } }; return@execute }
                            else -> { embedder.close(); null }
                        }
                        main.post { result.success(value) }
                    } catch (e: Exception) {
                        main.post { result.error(e.javaClass.simpleName, e.message, null) }
                    }
                }
            } else result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        documents.onActivityResult(requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == SEARCH_ACTION) {
            channel?.invokeMethod("openQuickSearch", null)
            intent.action = Intent.ACTION_MAIN
        }
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        worker.execute {
            if (::embedder.isInitialized) embedder.close()
            if (::pdfs.isInitialized) pdfs.close()
        }
        worker.shutdown()
        super.onDestroy()
    }

    companion object { const val SEARCH_ACTION = "com.arprovat.pocketsearch.SEARCH" }
}
