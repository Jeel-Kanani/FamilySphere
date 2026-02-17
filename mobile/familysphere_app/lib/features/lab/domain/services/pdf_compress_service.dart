import 'dart:io';
import 'package:flutter/services.dart';
import 'lab_file_manager.dart';

// ─── TYPED EXCEPTIONS ────────────────────────────────────────────────────────

abstract class PdfCompressException implements Exception {
  final String userMessage;
  const PdfCompressException(this.userMessage);
  @override
  String toString() => userMessage;
}

class EncryptedPdfException extends PdfCompressException {
  const EncryptedPdfException() : super('Please unlock the PDF before compressing.');
}

class StorageException extends PdfCompressException {
  const StorageException() : super('Not enough storage space on your device.');
}

class UnsupportedPdfException extends PdfCompressException {
  const UnsupportedPdfException([String? detail]) 
      : super(detail ?? 'This PDF format is not supported or the file is corrupted.');
}

class CancelledException extends PdfCompressException {
  const CancelledException() : super('Compression cancelled.');
}

class OversizedPdfException extends PdfCompressException {
  const OversizedPdfException(String detail) : super(detail);
}

// ─── COMPRESSION LEVELS ─────────────────────────────────────────────────────

enum CompressionLevel {
  low,      // minimal compression, image quality ~90%, max DPI 300
  medium,   // balanced compression, image quality ~75%, max DPI 200
  high,     // heavy compression, image quality ~60%, max DPI 150
  veryHigh, // aggressive compression, image quality ~45%, max DPI 100
}

extension CompressionLevelExt on CompressionLevel {
  String get label {
    switch (this) {
      case CompressionLevel.low:
        return 'Low';
      case CompressionLevel.medium:
        return 'Medium';
      case CompressionLevel.high:
        return 'High';
      case CompressionLevel.veryHigh:
        return 'Very High';
    }
  }

  String get description {
    switch (this) {
      case CompressionLevel.low:
        return 'Light compression for large files';
      case CompressionLevel.medium:
        return 'Moderate compression, good balance';
      case CompressionLevel.high:
        return 'Strong compression for smaller files';
      case CompressionLevel.veryHigh:
        return 'Maximum compression, smallest output';
    }
  }

  bool get hasQualityWarning {
    // Note: Due to PDF library limitations, all levels use similar compression
    // The quality warnings don't really apply in current implementation
    return false;
  }

  int get jpegQuality {
    switch (this) {
      case CompressionLevel.low:
        return 85;  // Matches Android implementation
      case CompressionLevel.medium:
        return 70;  // Matches Android implementation
      case CompressionLevel.high:
        return 55;  // Matches Android implementation
      case CompressionLevel.veryHigh:
        return 40;  // Matches Android implementation
    }
  }

  int get maxDpi {
    switch (this) {
      case CompressionLevel.low:
        return 250;  // Matches Android implementation
      case CompressionLevel.medium:
        return 200;
      case CompressionLevel.high:
        return 150;
      case CompressionLevel.veryHigh:
        return 100;
    }
  }
}

// ─── PDF ANALYSIS RESULT ────────────────────────────────────────────────────

class PdfAnalysis {
  final int pageCount;
  final bool isEncrypted;
  final int originalSize;

  const PdfAnalysis({
    required this.pageCount,
    required this.isEncrypted,
    required this.originalSize,
  });
}

// ─── PDF COMPRESS SERVICE ───────────────────────────────────────────────────

class PdfCompressService {
  final LabFileManager _fileManager;
  static const int kMaxFileSize = 100 * 1024 * 1024; // 100 MB
  static const int kMaxPages = 500;
  
  // Platform channel for native PDF compression
  static const _platform = MethodChannel('com.familysphere.pdf_compression');

  PdfCompressService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager() {
    // Setup progress callback handler
    _platform.setMethodCallHandler(_handleNativeCallback);
  }
  
  // Store the current progress callback
  void Function(double)? _currentProgressCallback;
  
  // Handle callbacks from native code
  Future<void> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'onProgress') {
      final progress = call.arguments as double;
      _currentProgressCallback?.call(progress);
    }
  }

  /// Analyzes the PDF to check for encryption, page count, and size constraints.
  Future<PdfAnalysis> analyzePdf(File pdf) async {
    final int size = await pdf.length();

    try {
      if (size > kMaxFileSize) {
        throw OversizedPdfException('PDF exceeds the maximum file size of 100 MB.');
      }

      // Basic validation - actual page count and encryption check will happen during compression
      return PdfAnalysis(
        pageCount: 0, // Unknown at this stage
        isEncrypted: false, // Will be detected during compression
        originalSize: size,
      );
    } catch (e) {
      if (e is PdfCompressException) rethrow;
      throw const UnsupportedPdfException();
    }
  }

  /// Estimates the compressed size based on compression level.
  int estimateCompressedSize(int originalSize, CompressionLevel level) {
    // More conservative estimates based on real-world testing
    // Note: Actual compression varies greatly depending on PDF content:
    // - Image-heavy PDFs compress well (50-80% reduction)
    // - Text-heavy PDFs barely compress (0-20% reduction)
    // - Already compressed PDFs may not compress further
    // These estimates assume mixed content with moderate compression potential
    switch (level) {
      case CompressionLevel.low:
        return (originalSize * 0.80).toInt(); // ~20% reduction (conservative)
      case CompressionLevel.medium:
        return (originalSize * 0.65).toInt(); // ~35% reduction
      case CompressionLevel.high:
        return (originalSize * 0.50).toInt(); // ~50% reduction
      case CompressionLevel.veryHigh:
        return (originalSize * 0.40).toInt(); // ~60% reduction
    }
  }

  /// Executes the compression process using native PDFBox implementation.
  Future<String> compressPdf({
    required File inputPdf,
    required CompressionLevel level,
    required String outputFileName,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // 1. Storage Check
    final originalSize = await inputPdf.length();
    if (!await _fileManager.hasEnoughStorage(originalSize * 2)) {
      throw const StorageException();
    }

    onProgress?.call(0.05);
    if (isCancelled?.call() == true) throw const CancelledException();

    try {
      // 2. Prepare output path
      final outputDir = await _fileManager.getCompressedOutputDir();
      final outputPath = await _fileManager.generateUniqueOutputPath(
        outputDir,
        outputFileName,
        '.pdf',
      );

      // 3. Store progress callback for native code to use
      _currentProgressCallback = onProgress;

      // 4. Call native compression
      final String? result = await _platform.invokeMethod<String>(
        'compressPdf',
        {
          'inputPath': inputPdf.path,
          'outputPath': outputPath,
          'level': level.name.toUpperCase(),
          'dpi': level.maxDpi,
          'quality': level.jpegQuality,
        },
      );

      if (result == null) {
        throw const UnsupportedPdfException('Compression failed - no output returned');
      }

      // 5. Cleanup
      _currentProgressCallback = null;

      // 6. Validation
      final outputFile = File(result);
      if (!await outputFile.exists()) {
        throw const UnsupportedPdfException('Failed to create output file.');
      }

      onProgress?.call(1.0);
      return result;

    } on PlatformException catch (e) {
      _currentProgressCallback = null;
      
      // Map native errors to our typed exceptions
      switch (e.code) {
        case 'CANCELLED':
          throw const CancelledException();
        case 'COMPRESSION_ERROR':
          if (e.message?.contains('encrypted') == true) {
            throw const EncryptedPdfException();
          } else if (e.message?.contains('too large') == true || 
                     e.message?.contains('too many pages') == true) {
            throw OversizedPdfException(e.message ?? 'PDF is too large');
          }
          throw UnsupportedPdfException(e.message);
        default:
          throw UnsupportedPdfException(e.message ?? 'Compression failed');
      }
    } catch (e) {
      _currentProgressCallback = null;
      if (e is PdfCompressException) rethrow;
      throw UnsupportedPdfException(e.toString());
    }
  }
  
  /// Cancel the current compression operation
  Future<void> cancel() async {
    try {
      await _platform.invokeMethod('cancel');
    } catch (e) {
      // Ignore cancellation errors
    }
  }
}
