import 'dart:io';
import 'dart:math';
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
  /// 0.0 = incompressible (text-heavy), 1.0 = highly compressible (image-heavy)
  final double compressibilityScore;

  const PdfAnalysis({
    required this.pageCount,
    required this.isEncrypted,
    required this.originalSize,
    required this.compressibilityScore,
  });
}

/// Holds estimated min and max compressed sizes.
class CompressionEstimate {
  final int min;
  final int max;
  /// Best single-point estimate (midpoint weighted toward likely result)
  int get best => ((min + max) / 2).toInt();

  const CompressionEstimate({required this.min, required this.max});
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

  /// Analyzes the PDF to check for encryption, page count, size constraints,
  /// and computes a compressibility score based on byte entropy.
  Future<PdfAnalysis> analyzePdf(File pdf) async {
    final int size = await pdf.length();

    try {
      if (size > kMaxFileSize) {
        throw OversizedPdfException('PDF exceeds the maximum file size of 100 MB.');
      }

      // Compute compressibility score from byte entropy analysis
      final score = await _computeCompressibilityScore(pdf, size);

      return PdfAnalysis(
        pageCount: 0, // Unknown at this stage
        isEncrypted: false, // Will be detected during compression
        originalSize: size,
        compressibilityScore: score,
      );
    } catch (e) {
      if (e is PdfCompressException) rethrow;
      throw const UnsupportedPdfException();
    }
  }

  /// Computes a compressibility score (0.0–1.0) by analyzing byte entropy.
  ///
  /// The native compressor renders each page as a bitmap and JPEG-recompresses it.
  /// Image-heavy PDFs (high entropy random pixel data) compress well via JPEG
  /// recompression, while text-heavy PDFs (low entropy, structured data) do not
  /// compress much because rasterizing text into images can actually increase size.
  ///
  /// Shannon entropy is measured on sampled bytes:
  /// - Entropy >= 7.5 → very image-heavy, highly compressible (score ~0.9)
  /// - Entropy ~6.0  → mixed content (score ~0.5)
  /// - Entropy <= 4.5 → text-heavy / already compressed, low compressibility (score ~0.1)
  Future<double> _computeCompressibilityScore(File pdf, int fileSize) async {
    try {
      final raf = await pdf.open();
      try {
        // Sample up to 16KB from multiple positions across the file
        const sampleSize = 4096;
        final positions = <int>[
          0, // Start (header — usually low entropy)
          (fileSize * 0.25).toInt(),
          (fileSize * 0.50).toInt(),
          (fileSize * 0.75).toInt(),
        ].where((p) => p < fileSize).toList();

        final allBytes = <int>[];
        for (final pos in positions) {
          raf.setPositionSync(pos);
          final readLen = (pos + sampleSize > fileSize) ? fileSize - pos : sampleSize;
          if (readLen <= 0) continue;
          final chunk = raf.readSync(readLen);
          allBytes.addAll(chunk);
        }

        if (allBytes.isEmpty) return 0.5;

        // Calculate Shannon entropy
        final freq = List<int>.filled(256, 0);
        for (final b in allBytes) {
          freq[b]++;
        }
        final total = allBytes.length.toDouble();
        double entropy = 0.0;
        for (final count in freq) {
          if (count == 0) continue;
          final p = count / total;
          entropy -= p * (p > 0 ? _log2(p) : 0);
        }
        // Max possible entropy is 8.0 (for 256 equally likely byte values)

        // Map entropy to compressibility score:
        // High entropy (>= 7.5) → image-heavy → score 0.85–0.95
        // Medium entropy (5.5–7.5) → mixed → score 0.35–0.85
        // Low entropy (<= 5.5) → text-heavy → score 0.05–0.35
        double score;
        if (entropy >= 7.5) {
          score = 0.85 + 0.10 * ((entropy - 7.5) / 0.5).clamp(0.0, 1.0);
        } else if (entropy >= 5.5) {
          score = 0.35 + 0.50 * ((entropy - 5.5) / 2.0).clamp(0.0, 1.0);
        } else {
          score = 0.05 + 0.30 * (entropy / 5.5).clamp(0.0, 1.0);
        }
        return score.clamp(0.0, 1.0);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return 0.5; // Default to medium if analysis fails
    }
  }

  static double _log2(double x) => x > 0 ? (log(x) / ln2) : 0;

  /// Estimates the compressed size range based on compression level and
  /// content compressibility score.
  CompressionEstimate estimateCompressedSize(
    int originalSize,
    CompressionLevel level,
    double compressibilityScore,
  ) {
    // Compression ratios: [minRatio, maxRatio] where ratio = output/input
    // Lower ratio = more compression
    // These are tuned per level and interpolated by compressibilityScore
    //
    // For image-heavy (score ~1.0): JPEG recompression is very effective
    // For text-heavy (score ~0.0): rasterization may even increase size

    // Ratios for text-heavy content (score = 0): minimal compression
    final textRatios = _textRatios(level);
    // Ratios for image-heavy content (score = 1): strong compression
    final imageRatios = _imageRatios(level);

    // Interpolate between text and image ratios based on score
    final s = compressibilityScore.clamp(0.0, 1.0);
    final minRatio = textRatios[0] + (imageRatios[0] - textRatios[0]) * s;
    final maxRatio = textRatios[1] + (imageRatios[1] - textRatios[1]) * s;

    final minSize = (originalSize * minRatio).toInt().clamp(1, originalSize);
    final maxSize = (originalSize * maxRatio).toInt().clamp(1, originalSize);

    return CompressionEstimate(
      min: minSize < maxSize ? minSize : maxSize,
      max: minSize < maxSize ? maxSize : minSize,
    );
  }

  /// Output/input ratios for text-heavy PDFs [min, max]
  List<double> _textRatios(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low:
        return [0.85, 1.05]; // may even grow slightly
      case CompressionLevel.medium:
        return [0.75, 0.95];
      case CompressionLevel.high:
        return [0.65, 0.90];
      case CompressionLevel.veryHigh:
        return [0.55, 0.85];
    }
  }

  /// Output/input ratios for image-heavy PDFs [min, max]
  List<double> _imageRatios(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low:
        return [0.55, 0.75];
      case CompressionLevel.medium:
        return [0.35, 0.55];
      case CompressionLevel.high:
        return [0.20, 0.40];
      case CompressionLevel.veryHigh:
        return [0.10, 0.30];
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
