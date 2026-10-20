package com.arprovat.pocketsearch

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

class DocumentAccess(private val activity: Activity) {
    private var pickerResult: MethodChannel.Result? = null
    private var pickerCode = 0
    private val supported = setOf("pdf", "txt", "md", "doc", "docx", "ppt", "pptx")

    fun pickFiles(result: MethodChannel.Result) {
        if (pickerResult != null) { result.error("PICKER_BUSY", "Picker already open", null); return }
        pickerResult = result; pickerCode = 701
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, pickerCode)
    }

    fun pickFolder(result: MethodChannel.Result) {
        if (pickerResult != null) { result.error("PICKER_BUSY", "Picker already open", null); return }
        pickerResult = result; pickerCode = 702
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, pickerCode)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != pickerCode || pickerResult == null) return false
        val result = pickerResult!!
        pickerResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(if (requestCode == 701) emptyList<Any>() else null)
            return true
        }
        try {
            val flags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (requestCode == 702) {
                val uri = data.data ?: throw IllegalStateException("No folder URI")
                persist(uri, flags)
                result.success(mapOf("uri" to uri.toString(),
                    "name" to DocumentsContract.getTreeDocumentId(uri).substringAfterLast('/')))
            } else {
                val uris = mutableListOf<Uri>()
                data.data?.let(uris::add)
                data.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
                }
                result.success(uris.distinct().map { uri ->
                    persist(uri, flags)
                    metadata(uri)
                })
            }
        } catch (e: Exception) { result.error("PICKER_ERROR", e.message, null) }
        return true
    }

    private fun persist(uri: Uri, flags: Int) {
        if (flags != 0) try {
            activity.contentResolver.takePersistableUriPermission(uri, flags)
        } catch (_: SecurityException) { /* Some providers grant only session access. */ }
    }

    private fun metadata(uri: Uri): Map<String, Any?> {
        var display = uri.lastPathSegment ?: "Document"
        var size: Long? = null
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
            if (it.moveToFirst()) {
                display = it.getString(0) ?: display
                if (!it.isNull(1)) size = it.getLong(1)
            }
        }
        return mapOf("uri" to uri.toString(), "name" to display,
            "mime" to (activity.contentResolver.getType(uri) ?: "application/octet-stream"),
            "size" to size)
    }

    fun listFolder(tree: Uri): List<Map<String, Any?>> {
        val found = mutableListOf<Map<String, Any?>>()
        val folders = ArrayDeque<String>()
        folders.add(DocumentsContract.getTreeDocumentId(tree))
        while (folders.isNotEmpty()) {
            val parent = folders.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
            activity.contentResolver.query(children, arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE), null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getString(0)
                    val name = cursor.getString(1) ?: continue
                    val mime = cursor.getString(2) ?: "application/octet-stream"
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        folders.add(id)
                    } else if (name.substringAfterLast('.', "").lowercase() in supported) {
                        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                        found.add(mapOf("uri" to uri.toString(), "name" to name,
                            "mime" to mime, "size" to if (cursor.isNull(3)) null else cursor.getLong(3)))
                    }
                }
            }
        }
        return found
    }

    fun readText(uri: Uri): String {
        val bytes = activity.contentResolver.openInputStream(uri)?.use { stream ->
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(65536)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                if (output.size() + count > 16 * 1024 * 1024)
                    throw IllegalArgumentException("Text file exceeds the 16 MB import limit")
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: throw SecurityException("Cannot open selected document")
        val start = if (bytes.size >= 3 && bytes[0] == 0xEF.toByte() &&
            bytes[1] == 0xBB.toByte() && bytes[2] == 0xBF.toByte()) 3 else 0
        return try {
            StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes, start, bytes.size - start)).toString()
        } catch (_: CharacterCodingException) {
            throw IllegalArgumentException("Unsupported text encoding; save this file as UTF-8")
        }
    }

    fun openSource(uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, activity.contentResolver.getType(uri) ?: "*/*")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try { activity.startActivity(intent) }
        catch (_: ActivityNotFoundException) { throw IllegalStateException("No app can open this document") }
    }
}
