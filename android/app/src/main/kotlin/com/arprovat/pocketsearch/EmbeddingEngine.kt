package com.arprovat.pocketsearch

import android.content.Context
import android.os.SystemClock
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import java.io.File
import java.net.URL
import java.security.MessageDigest
import kotlin.math.sqrt

// All calls, including close, run on the bridge's single worker.
class EmbeddingEngine(private val context: Context) {
    private var model: TextEmbedder? = null
    private var loadMs = 0L
    private val modelFile = File(context.filesDir, "embedding_gemma.task")
    private val digestFile = File(context.filesDir, "embedding_gemma.sha256")
    private val modelUrl = "https://storage.googleapis.com/mediapipe-models/text_embedder/embedding_gemma/int4int8/latest/embedding_gemma.task"

    fun status(): Map<String, Any> = mapOf("ready" to modelFile.exists(),
        "bytes" to if (modelFile.exists()) modelFile.length() else 0L,
        "url" to modelUrl)

    fun download() {
        if (modelFile.exists()) return
        val temporary = File(context.filesDir, "embedding_gemma.task.part")
        try {
            val connection = URL(modelUrl).openConnection().apply {
                connectTimeout = 15000; readTimeout = 30000
            }
            connection.getInputStream().use { input ->
                temporary.outputStream().use { output -> input.copyTo(output, 65536) }
            }
            require(temporary.length() > 100_000_000L) { "Model download was incomplete" }
            require(temporary.renameTo(modelFile)) { "Could not save model" }
            digestFile.delete()
            digestFile.writeText(digest())
            initialize()
        } catch (e: Exception) {
            temporary.delete()
            modelFile.delete()
            digestFile.delete()
            throw e
        }
    }

    private fun digest(): String {
        if (digestFile.exists()) return digestFile.readText().trim()
        val hash = MessageDigest.getInstance("SHA-256")
        modelFile.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val size = input.read(buffer)
                if (size < 0) break
                hash.update(buffer, 0, size)
            }
        }
        return hash.digest().joinToString("") { "%02x".format(it) }
    }

    fun initialize(): Map<String, Any> {
        check(modelFile.exists()) { "EmbeddingGemma model required; download it in Setup" }
        if (model == null) {
            val started = SystemClock.elapsedRealtime()
            model = TextEmbedder.createFromFile(context, modelFile)
            loadMs = SystemClock.elapsedRealtime() - started
        }
        return mapOf("model" to "embedding_gemma/task/256/${digest().take(16)}", "loadMs" to loadMs,
            "normalization" to "L2", "runtime" to "MediaPipe tasks-text")
    }

    fun embed(text: String, document: Boolean = false, title: String = "none"): List<Double> {
        require(text.isNotBlank() && text.length <= 4096) { "Text must be 1-4096 characters" }
        val context = TextEmbedder.TextFormatContext.builder()
            .setTaskType(if (document)
                TextEmbedder.EmbeddingType.RETRIEVAL_DOCUMENT
                else TextEmbedder.EmbeddingType.RETRIEVAL_QUERY)
            .setRole(if (document) TextEmbedder.TextRole.DOCUMENT else TextEmbedder.TextRole.QUERY)
            .setTitle(title)
            .build()
        val values = checkNotNull(model) { "Initialize the model first" }
            .embed(text, context).embeddingResult().embeddings().first().floatEmbedding()
        require(values.size >= 256 && values.all { it.isFinite() }) { "Invalid embedding" }
        val first = values.take(256)
        val norm = sqrt(first.sumOf { it.toDouble() * it.toDouble() })
        require(norm > 0 && norm.isFinite()) { "Invalid vector norm" }
        return first.map { it.toDouble() / norm }
    }

    fun close() { model?.close(); model = null }
}
