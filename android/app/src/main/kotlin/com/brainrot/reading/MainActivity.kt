package com.brainrot.reading

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "reading.documents"
    private val exportRequestCode = 5001
    private val importRequestCode = 5002
    private var pendingResult: MethodChannel.Result? = null
    private var pendingExportContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportText" -> {
                    val fileName = call.argument<String>("fileName") ?: "reading-feeds.opml"
                    val mimeType = call.argument<String>("mimeType") ?: "text/x-opml"
                    val content = call.argument<String>("content") ?: ""
                    exportText(fileName, mimeType, content, result)
                }
                "importText" -> {
                    val mimeTypes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    importText(mimeTypes, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun exportText(
        fileName: String,
        mimeType: String,
        content: String,
        result: MethodChannel.Result,
    ) {
        if (pendingResult != null) {
            result.error("busy", "Another file operation is already running.", null)
            return
        }

        pendingResult = result
        pendingExportContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        startActivityForResult(intent, exportRequestCode)
    }

    private fun importText(
        mimeTypes: List<String>,
        result: MethodChannel.Result,
    ) {
        if (pendingResult != null) {
            result.error("busy", "Another file operation is already running.", null)
            return
        }

        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            if (mimeTypes.isNotEmpty()) {
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            }
        }
        startActivityForResult(intent, importRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            exportRequestCode -> handleExportResult(resultCode, data?.data)
            importRequestCode -> handleImportResult(resultCode, data?.data)
        }
    }

    private fun handleExportResult(resultCode: Int, uri: Uri?) {
        val result = pendingResult ?: return
        val content = pendingExportContent ?: ""
        clearPending()

        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }

        try {
            contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(content.toByteArray(Charsets.UTF_8))
            } ?: throw IllegalStateException("Could not open output stream.")
            result.success(true)
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        }
    }

    private fun handleImportResult(resultCode: Int, uri: Uri?) {
        val result = pendingResult ?: return
        clearPending()

        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        try {
            val text = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8).use { reader ->
                reader?.readText()
            } ?: throw IllegalStateException("Could not open input stream.")
            result.success(text)
        } catch (error: Exception) {
            result.error("import_failed", error.message, null)
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingExportContent = null
    }
}
