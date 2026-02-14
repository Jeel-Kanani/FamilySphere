import 'dart:io';
import 'package:image/image.dart' as img;
import 'lab_file_manager.dart';

// ─── TYPED ERROR CATEGORIES ─────────────────────────────────────────────────

abstract class ImageResizeError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const ImageResizeError(this.userMessage, [this.technicalDetail]);

  @override
  String toString() => userMessage;
}

class ImageLoadError extends ImageResizeError {
  const ImageLoadError(super.userMessage, [super.technicalDetail]);
}

class ImageProcessError extends ImageResizeError {
  const ImageProcessError(super.userMessage, [super.technicalDetail]);
}

class ImageSaveError extends ImageResizeError {
  const ImageSaveError(super.userMessage, [super.technicalDetail]);
}

class ResizeCancelledError extends ImageResizeError {
  const ResizeCancelledError()
      : super('Resize operation cancelled. No files were changed.');
}

// ─── RESIZE MODES & FORMATS ──────────────────────────────────────────────────

enum ImageResizeMode {
  percentage('By Percentage'),
  width('By Width'),
  height('By Height'),
  fit('Fit Within Box');

  final String label;
  const ImageResizeMode(this.label);
}

enum ImageOutputFormat {
  original('Same as original'),
  jpg('JPG'),
  png('PNG'),
  webp('WebP');

  final String label;
  const ImageOutputFormat(this.label);
}

// ─── RESIZE RESULT ──────────────────────────────────────────────────────────

class ImageResizeResult {
  final String outputPath;
  final int outputSizeBytes;
  final int width;
  final int height;
  final Duration duration;

  const ImageResizeResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
    required this.duration,
  });
}

// ─── IMAGE RESIZE SERVICE ─────────────────────────────────────────────────────

class ImageResizeService {
  final LabFileManager _fileManager;

  ImageResizeService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Resizes an image based on the provided configuration.
  Future<ImageResizeResult> resizeImage({
    required File inputFile,
    required String outputFileName,
    required ImageResizeMode mode,
    required ImageOutputFormat format,
    double? percentage,
    int? targetWidth,
    int? targetHeight,
    bool lockAspectRatio = true,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Load Image
    onProgress?.call(0.1, 'Loading image...');
    final bytes = await inputFile.readAsBytes();
    if (isCancelled?.call() == true) throw const ResizeCancelledError();

    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const ImageLoadError('Could not decode image. Format might be unsupported.');
    }

    if (isCancelled?.call() == true) throw const ResizeCancelledError();

    // 2. Process Resizing
    onProgress?.call(0.4, 'Resizing image...');
    img.Image resized;

    final originalWidth = image.width;
    final originalHeight = image.height;

    switch (mode) {
      case ImageResizeMode.percentage:
        final scale = (percentage ?? 50) / 100;
        final w = (originalWidth * scale).round();
        final h = (originalHeight * scale).round();
        resized = img.copyResize(image, width: w, height: h, interpolation: img.Interpolation.cubic);
        break;

      case ImageResizeMode.width:
        final w = targetWidth ?? originalWidth;
        resized = img.copyResize(
          image,
          width: w,
          height: lockAspectRatio ? null : (targetHeight ?? originalHeight),
          interpolation: img.Interpolation.cubic,
        );
        break;

      case ImageResizeMode.height:
        final h = targetHeight ?? originalHeight;
        resized = img.copyResize(
          image,
          height: h,
          width: lockAspectRatio ? null : (targetWidth ?? originalWidth),
          interpolation: img.Interpolation.cubic,
        );
        break;

      case ImageResizeMode.fit:
        final maxW = targetWidth ?? originalWidth;
        final maxH = targetHeight ?? originalHeight;
        resized = img.copyResize(
          image,
          width: maxW,
          height: maxH,
          maintainAspect: true,
          interpolation: img.Interpolation.cubic,
        );
        break;
    }

    if (isCancelled?.call() == true) throw const ResizeCancelledError();

    // 3. Encode & Save
    onProgress?.call(0.7, 'Saving image...');
    
    // Determine format
    var finalFormat = format;
    if (format == ImageOutputFormat.original) {
      final ext = inputFile.path.split('.').last.toLowerCase();
      if (ext == 'png') {
        finalFormat = ImageOutputFormat.png;
      } else if (ext == 'webp') {
        finalFormat = ImageOutputFormat.webp;
      } else {
        finalFormat = ImageOutputFormat.jpg; // Default to JPG
      }
    }

    List<int> encodedBytes;
    String extension;
    switch (finalFormat) {
      case ImageOutputFormat.png:
        encodedBytes = img.encodePng(resized);
        extension = '.png';
        break;
      case ImageOutputFormat.webp:
        encodedBytes = img.encodePng(resized); // WebP encoding not available in this version, using PNG
        extension = '.png';
        break;
      case ImageOutputFormat.jpg:
      default:
        encodedBytes = img.encodeJpg(resized, quality: 90);
        extension = '.jpg';
        break;
    }

    final outputDir = await _fileManager.getOutputDir('ResizeImage');
    
    // Ensure filename has correct extension
    var baseName = outputFileName;
    if (baseName.contains('.')) {
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }
    
    final outputPath = await _fileManager.generateUniqueOutputPath(
      outputDir,
      baseName,
      extension,
    );

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedBytes);

    stopwatch.stop();
    onProgress?.call(1.0, 'Done!');

    return ImageResizeResult(
      outputPath: outputPath,
      outputSizeBytes: encodedBytes.length,
      width: resized.width,
      height: resized.height,
      duration: stopwatch.elapsed,
    );
  }
}
