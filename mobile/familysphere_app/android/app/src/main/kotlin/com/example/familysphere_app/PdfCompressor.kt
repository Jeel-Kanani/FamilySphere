package com.example.familysphere_app

import android.content.Context
import android.graphics.Bitmap
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.graphics.image.JPEGFactory
import com.tom_roush.pdfbox.pdmodel.graphics.image.PDImageXObject
import com.tom_roush.pdfbox.rendering.PDFRenderer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PDF Compression Backend using PDFBox-Android
 * Provides true image recompression with multiple quality levels
 */
class PdfCompressor(private val context: Context) {

    companion object {
        const val MAX_FILE_SIZE = 100 * 1024 * 1024L // 100 MB
        const val MAX_PAGES = 500
    }

    private val isCancelled = AtomicBoolean(false)

    init {
        // Initialize PDFBox resources
        PDFBoxResourceLoader.init(context)
    }

    /**
     * Compression configuration
     */
    data class CompressionConfig(
        val dpi: Int,
        val jpegQuality: Int
    )

    /**
     * Compression level configuration (for backwards compatibility)
     */
    enum class CompressionLevel(
        val dpi: Int,
        val jpegQuality: Int,
        val displayName: String
    ) {
        LOW(250, 85, "Low"),
        MEDIUM(200, 70, "Medium"),
        HIGH(150, 55, "High"),
        VERY_HIGH(100, 40, "Very High");

        companion object {
            fun fromString(value: String): CompressionLevel {
                return values().find { it.name.equals(value, ignoreCase = true) } ?: MEDIUM
            }
        }
    }

    /**
     * Cancel the current compression operation
     */
    fun cancel() {
        isCancelled.set(true)
    }

    /**
     * Compress a PDF file with image recompression
     */
    suspend fun compressPdf(
        inputPath: String,
        outputPath: String,
        config: CompressionConfig,
        onProgress: (Double) -> Unit
    ): String = withContext(Dispatchers.IO) {
        isCancelled.set(false)
        var document: PDDocument? = null
        var outputDoc: PDDocument? = null
        val tempFile = File(context.cacheDir, "temp_compress_${UUID.randomUUID()}.pdf")

        try {
            // 1. Validation
            val inputFile = File(inputPath)
            validateFile(inputFile)
            onProgress(0.05)

            if (isCancelled.get()) throw CancellationException()

            // 2. Load PDF
            document = PDDocument.load(inputFile)
            val pageCount = document.numberOfPages

            if (pageCount > MAX_PAGES) {
                throw IOException("PDF has too many pages ($pageCount). Maximum: $MAX_PAGES")
            }

            if (document.isEncrypted) {
                throw IOException("PDF is encrypted. Please unlock it first.")
            }

            onProgress(0.1)

            // 3. Create output document
            outputDoc = PDDocument()
            val renderer = PDFRenderer(document)

            // 4. Process each page
            for (i in 0 until pageCount) {
                if (isCancelled.get()) throw CancellationException()

                val sourcePage = document.getPage(i)
                val targetPage = PDPage(sourcePage.mediaBox)
                outputDoc.addPage(targetPage)

                // Render page as image and recompress
                compressPage(renderer, i, outputDoc, targetPage, config)

                val progress = 0.1 + (0.7 * (i + 1) / pageCount)
                onProgress(progress)
            }

            // 5. Save to temp file
            outputDoc.save(tempFile)
            onProgress(0.85)

            // 6. Copy to final location
            tempFile.copyTo(File(outputPath), overwrite = true)
            onProgress(0.95)

            // 7. Cleanup
            document.close()
            outputDoc.close()
            tempFile.delete()

            onProgress(1.0)
            outputPath

        } catch (e: Exception) {
            document?.close()
            outputDoc?.close()
            tempFile.delete()

            when (e) {
                is CancellationException -> throw e
                else -> throw IOException("Compression failed: ${e.message}")
            }
        }
    }

    /**
     * Compress a single page by rendering and recompressing
     */
    private fun compressPage(
        renderer: PDFRenderer,
        pageIndex: Int,
        outputDoc: PDDocument,
        targetPage: PDPage,
        config: CompressionConfig
    ) {
        // Calculate DPI for rendering
        val dpi = config.dpi.toFloat()

        // Render page as bitmap
        val bitmap = renderer.renderImage(pageIndex, dpi / 72f) // 72 DPI is base

        // Compress bitmap as JPEG
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, config.jpegQuality, outputStream)
        val jpegBytes = outputStream.toByteArray()

        // Create PDImage from JPEG bytes
        val pdImage = JPEGFactory.createFromByteArray(outputDoc, jpegBytes)

        // Draw image on page
        val contentStream = PDPageContentStream(outputDoc, targetPage)
        contentStream.drawImage(
            pdImage,
            0f,
            0f,
            targetPage.mediaBox.width,
            targetPage.mediaBox.height
        )
        contentStream.close()

        // Cleanup
        bitmap.recycle()
    }

    /**
     * Validate file before processing
     */
    private fun validateFile(file: File) {
        if (!file.exists()) {
            throw IOException("File not found: ${file.path}")
        }

        if (file.length() > MAX_FILE_SIZE) {
            val sizeMB = file.length() / (1024 * 1024)
            throw IOException("File too large (${sizeMB}MB). Maximum: 100MB")
        }

        if (!file.name.endsWith(".pdf", ignoreCase = true)) {
            throw IOException("File must be a PDF")
        }
    }

    /**
     * Custom exception for cancellation
     */
    class CancellationException : Exception("Operation cancelled by user")
}
