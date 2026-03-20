import 'dart:io';
import 'package:image/image.dart' as img;
import 'lab_file_manager.dart';

// ─── TYPED ERRORS ────────────────────────────────────────────────────────────

abstract class ImageConvertError implements Exception {
  final String userMessage;
  const ImageConvertError(this.userMessage);
  @override
  String toString() => userMessage;
}

class ConvertLoadError extends ImageConvertError {
  const ConvertLoadError(super.userMessage);
}

class ConvertProcessError extends ImageConvertError {
  const ConvertProcessError(super.userMessage);
}

// ─── TARGET FORMATS ─────────────────────────────────────────────────────────

enum ConvertFormat {
  jpg('JPG', '.jpg'),
  png('PNG', '.png'),
  bmp('BMP', '.bmp');

  final String label;
  final String extension;
  const ConvertFormat(this.label, this.extension);
}

// ─── RESULT ─────────────────────────────────────────────────────────────────

class ImageConvertResult {
  final String outputPath;
  final int outputSizeBytes;
  final String sourceFormat;
  final String targetFormat;
  final int width;
  final int height;
  final Duration duration;

  const ImageConvertResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.sourceFormat,
    required this.targetFormat,
    required this.width,
    required this.height,
    required this.duration,
  });
}

// ─── IMAGE CONVERT SERVICE ──────────────────────────────────────────────────

class ImageConvertService {
  final LabFileManager _fileManager;

  ImageConvertService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  Future<ImageConvertResult> convertImage({
    required File inputFile,
    required String outputFileName,
    required ConvertFormat targetFormat,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Load
    onProgress?.call(0.1, 'Loading image...');
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const ConvertLoadError('Could not decode image. Format might be unsupported.');
    }

    final sourceExt = inputFile.path.split('.').last.toUpperCase();

    // 2. Encode to target format
    onProgress?.call(0.4, 'Converting to ${targetFormat.label}...');
    List<int> encodedBytes;
    switch (targetFormat) {
      case ConvertFormat.jpg:
        encodedBytes = img.encodeJpg(image, quality: 90);
        break;
      case ConvertFormat.png:
        encodedBytes = img.encodePng(image);
        break;
      case ConvertFormat.bmp:
        encodedBytes = img.encodeBmp(image);
        break;
    }

    // 3. Save
    onProgress?.call(0.8, 'Saving...');
    final outputDir = await _fileManager.getOutputDir('ConvertImage');

    var baseName = outputFileName;
    if (baseName.contains('.')) {
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }

    final outputPath = await _fileManager.generateUniqueOutputPath(
      outputDir, baseName, targetFormat.extension,
    );

    await File(outputPath).writeAsBytes(encodedBytes);

    stopwatch.stop();
    onProgress?.call(1.0, 'Done!');

    return ImageConvertResult(
      outputPath: outputPath,
      outputSizeBytes: encodedBytes.length,
      sourceFormat: sourceExt,
      targetFormat: targetFormat.label,
      width: image.width,
      height: image.height,
      duration: stopwatch.elapsed,
    );
  }
}
