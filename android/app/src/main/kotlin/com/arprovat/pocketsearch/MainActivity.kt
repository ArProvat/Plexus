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
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        embedder = EmbeddingEngine(applicationContext)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.arprovat.pocketsearch/native")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method == "consumeSearchLaunch") {
                result.success(intent.action == SEARCH_ACTION)
                intent.action = Intent.ACTION_MAIN
            } else if (call.method in setOf("initializeEmbedding", "embedQuery", "embedDocuments", "disposeEmbedding")) {
                worker.execute {
                    try {
                        val value: Any? = when (call.method) {
                            "initializeEmbedding" -> embedder.initialize()
                            "embedQuery" -> embedder.embed(call.arguments as? String
                                ?: throw IllegalArgumentException("Expected query text"))
                            "embedDocuments" -> {
                                val texts = call.arguments as? List<*>
                                    ?: throw IllegalArgumentException("Expected passages")
                                require(texts.size in 1..8) { "Batch size must be 1-8" }
                                texts.map { embedder.embed(it as? String
                                    ?: throw IllegalArgumentException("Expected text")) }
                            }
                            else -> { embedder.close(); null }
                        }
                        main.post { result.success(value) }
                    } catch (e: Exception) {
                        main.post { result.error("LOCAL_EMBEDDING_ERROR", e.message, null) }
                    }
                }
            } else result.notImplemented()
        }
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
        worker.execute { if (::embedder.isInitialized) embedder.close() }
        worker.shutdown()
        super.onDestroy()
    }

    companion object { const val SEARCH_ACTION = "com.arprovat.pocketsearch.SEARCH" }
}
