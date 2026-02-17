package com.example.familysphere_app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val DOWNLOADS_CHANNEL = "com.familysphere.downloads"
    private val COMPRESSION_CHANNEL = "com.familysphere.pdf_compression"
    private lateinit var pdfCompressor: PdfCompressor
    private lateinit var compressionChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize PDF compressor
        pdfCompressor = PdfCompressor(applicationContext)
        
        // Setup downloads channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOADS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    
                    if (sourcePath != null && fileName != null) {
                        try {
                            val savedPath = saveFileToDownloads(sourcePath, fileName)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "sourcePath and fileName required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Setup PDF compression channel
        compressionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMPRESSION_CHANNEL)
        compressionChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "compressPdf" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val levelString = call.argument<String>("level") ?: "MEDIUM"
                    val dpi = call.argument<Int>("dpi")
                    val quality = call.argument<Int>("quality")
                    
                    if (inputPath != null && outputPath != null) {
                        // Use explicit DPI/quality if provided, otherwise use level enum
                        val config = if (dpi != null && quality != null) {
                            PdfCompressor.CompressionConfig(dpi, quality)
                        } else {
                            val level = PdfCompressor.CompressionLevel.fromString(levelString)
                            PdfCompressor.CompressionConfig(level.dpi, level.jpegQuality)
                        }
                        
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                val finalPath = pdfCompressor.compressPdf(
                                    inputPath = inputPath,
                                    outputPath = outputPath,
                                    config = config
                                ) { progress ->
                                    // Send progress updates to Flutter on main thread
                                    CoroutineScope(Dispatchers.Main).launch {
                                        compressionChannel.invokeMethod("onProgress", progress)
                                    }
                                }
                                result.success(finalPath)
                            } catch (e: PdfCompressor.CancellationException) {
                                result.error("CANCELLED", "Compression cancelled", null)
                            } catch (e: Exception) {
                                result.error("COMPRESSION_ERROR", e.message, null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "inputPath and outputPath required", null)
                    }
                }
                "cancel" -> {
                    pdfCompressor.cancel()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveFileToDownloads(sourcePath: String, fileName: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw Exception("Source file not found: $sourcePath")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ - Use MediaStore
            val resolver = contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, getMimeType(fileName))
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }

            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create MediaStore entry")

            resolver.openOutputStream(uri)?.use { outputStream ->
                FileInputStream(sourceFile).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            } ?: throw Exception("Failed to open output stream")

            // Get the actual file path
            val projection = arrayOf(MediaStore.MediaColumns.DATA)
            resolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val columnIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                    return cursor.getString(columnIndex) ?: uri.toString()
                }
            }
            return uri.toString()
        } else {
            // Android 9 and below - Direct file copy
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }

            var destFile = File(downloadsDir, fileName)
            var counter = 1
            while (destFile.exists()) {
                val nameParts = fileName.split(".")
                val newName = if (nameParts.size > 1) {
                    val ext = nameParts.last()
                    val baseName = nameParts.dropLast(1).joinToString(".")
                    "$baseName ($counter).$ext"
                } else {
                    "$fileName ($counter)"
                }
                destFile = File(downloadsDir, newName)
                counter++
            }

            sourceFile.copyTo(destFile, overwrite = false)
            return destFile.absolutePath
        }
    }

    private fun getMimeType(fileName: String): String {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "pdf" -> "application/pdf"
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "application/octet-stream"
        }
    }
}

