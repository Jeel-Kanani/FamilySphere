import 'dart:io';
import 'package:image/image.dart' as img;
import 'lab_file_manager.dart';

// ─── TYPED ERRORS ────────────────────────────────────────────────────────────

abstract class ImageCompressError implements Exception {
  final String userMessage;
  const ImageCompressError(this.userMessage);
  @override
  String toString() => userMessage;
}

class CompressLoadError extends ImageCompressError {
  const CompressLoadError(super.userMessage);
}

class CompressProcessError extends ImageCompressError {
  const CompressProcessError(super.userMessage);
}

class CompressCancelledError extends ImageCompressError {
  const CompressCancelledError() : super('Compression cancelled.');
}

// ─── QUALITY LEVELS ─────────────────────────────────────────────────────────

enum ImageQuality {
  high('High Quality', 85, 'Minimal compression, best quality'),
  medium('Medium', 70, 'Balanced quality and file size'),
  low('Low', 55, 'Smaller file, reduced quality'),
  veryLow('Maximum Compression', 35, 'Smallest file, noticeable quality loss');

  final String label;
  final int jpegQuality;
  final String description;
  const ImageQuality(this.label, this.jpegQuality, this.description);
}

// ─── RESULT ─────────────────────────────────────────────────────────────────

class ImageCompressResult {
  final String outputPath;
  final int originalSize;
  final int compressedSize;
  final int width;
  final int height;
  final Duration duration;

  const ImageCompressResult({
    required this.outputPath,
    required this.originalSize,
    required this.compressedSize,
    required this.width,
    required this.height,
    required this.duration,
  });

  double get savingsPercent =>
      originalSize > 0 ? ((originalSize - compressedSize) / originalSize * 100) : 0;
}

// ─── IMAGE COMPRESS SERVICE ─────────────────────────────────────────────────

class ImageCompressService {
  final LabFileManager _fileManager;

  ImageCompressService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  Future<ImageCompressResult> compressImage({
    required File inputFile,
    required String outputFileName,
    required ImageQuality quality,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final originalSize = await inputFile.length();

    // 1. Load
    onProgress?.call(0.1, 'Loading image...');
    final bytes = await inputFile.readAsBytes();
    if (isCancelled?.call() == true) throw const CompressCancelledError();

    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const CompressLoadError('Could not decode image. Format might be unsupported.');
    }

    if (isCancelled?.call() == true) throw const CompressCancelledError();

    // 2. Compress (re-encode as JPEG with specified quality)
    onProgress?.call(0.4, 'Compressing...');
    final compressed = img.encodeJpg(image, quality: quality.jpegQuality);

    if (isCancelled?.call() == true) throw const CompressCancelledError();

    // 3. Save
    onProgress?.call(0.8, 'Saving...');
    final outputDir = await _fileManager.getOutputDir('CompressImage');

    var baseName = outputFileName;
    if (baseName.contains('.')) {
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }

    final outputPath = await _fileManager.generateUniqueOutputPath(
      outputDir, baseName, '.jpg',
    );

    await File(outputPath).writeAsBytes(compressed);

    stopwatch.stop();
    onProgress?.call(1.0, 'Done!');

    return ImageCompressResult(
      outputPath: outputPath,
      originalSize: originalSize,
      compressedSize: compressed.length,
      width: image.width,
      height: image.height,
      duration: stopwatch.elapsed,
    );
  }
}
