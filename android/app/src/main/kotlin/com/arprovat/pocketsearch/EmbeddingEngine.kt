package com.arprovat.pocketsearch

import android.content.Context
import android.os.SystemClock
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import kotlin.math.sqrt

// All calls, including close, run on the bridge's single worker.
class EmbeddingEngine(private val context: Context) {
    private var model: TextEmbedder? = null
    private var loadMs = 0L

    fun initialize(): Map<String, Any> {
        if (model == null) {
            val started = SystemClock.elapsedRealtime()
            val options = TextEmbedder.TextEmbedderOptions.builder()
                .setBaseOptions(BaseOptions.builder()
                    .setModelAssetPath("mobile_bert.tflite").build())
                .build()
            model = TextEmbedder.createFromOptions(context, options)
            loadMs = SystemClock.elapsedRealtime() - started
        }
        return mapOf("model" to "mobile_bert/float32/1", "loadMs" to loadMs,
            "normalization" to "L2", "runtime" to "MediaPipe tasks-text")
    }

    fun embed(text: String): List<Double> {
        require(text.isNotBlank() && text.length <= 4096) { "Text must be 1-4096 characters" }
        val values = checkNotNull(model) { "Initialize the model first" }
            .embed(text).embeddingResult().embeddings().first().floatEmbedding()
        require(values.isNotEmpty() && values.all { it.isFinite() }) { "Invalid embedding" }
        val norm = sqrt(values.sumOf { it.toDouble() * it.toDouble() })
        require(norm > 0 && norm.isFinite()) { "Invalid vector norm" }
        return values.map { it.toDouble() / norm }
    }

    fun close() { model?.close(); model = null }
}
