import 'dart:io';
import 'package:image/image.dart' as img;
import 'lab_file_manager.dart';

// ─── ERROR DEFINITIONS ──────────────────────────────────────────────────────

abstract class CropImageError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  final bool recoverable;
  const CropImageError(this.userMessage, {this.technicalDetail, this.recoverable = false});
  @override
  String toString() => userMessage;
}

class ValidationError extends CropImageError {
  const ValidationError(super.userMessage, {super.technicalDetail, super.recoverable = true});
}

class ImageProcessError extends CropImageError {
  const ImageProcessError(super.userMessage, {super.technicalDetail, super.recoverable = false});
}

class StorageError extends CropImageError {
  const StorageError(super.userMessage, {super.technicalDetail, super.recoverable = true});
}

// ─── DATA MODELS ───────────────────────────────────────────────────────────

enum ImageOutputFormat {
  jpg('JPG (High Quality)'),
  png('PNG (Lossless)'),
  webp('WebP (Efficient)'),
  original('Same as Original');

  final String label;
  const ImageOutputFormat(this.label);
}

class CropResult {
  final String outputPath;
  final int outputSizeBytes;
  final int width;
  final int height;
  final Duration duration;

  const CropResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
    required this.duration,
  });
}

// ─── CROP IMAGE SERVICE ─────────────────────────────────────────────────────

class CropImageService {
  final LabFileManager _fileManager;
  final String _toolId = 'crop_image';

  CropImageService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Refined Crop functionality following the Common Lab Engine Spec.
  Future<CropResult> processImage({
    required File inputFile,
    required String outputFileName,
    required ImageOutputFormat format,
    required double cropX, // Normalized 0-1
    required double cropY, // Normalized 0-1
    required double cropWidth, // Normalized 0-1
    required double cropHeight, // Normalized 0-1
    required int rotation, // 0, 90, 180, 270
    required bool flipHorizontal,
    required bool flipVertical,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    Directory? tempDir;

    try {
      // 1. Validation Phase
      onProgress?.call(0.05, 'Validating file...');
      if (!await inputFile.exists()) {
        throw const ValidationError('Original image file not found.');
      }

      final int fileSize = await inputFile.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw const ValidationError('Image size exceeds 50MB limit.');
      }

      final ext = inputFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        throw ValidationError('Unsupported image format: $ext');
      }

      onProgress?.call(0.1, 'Checking storage...');
      if (!await _fileManager.hasEnoughStorage(fileSize)) {
        throw const StorageError('Insufficient storage. At least 2× image size is required.');
      }

      // 2. Lab Tool Context Initialization & 3. File Preparation
      onProgress?.call(0.15, 'Preparing workspace...');
      tempDir = await _fileManager.getTempDir(_toolId);
      final tempFile = File('${tempDir.path}/input_source.$ext');
      await inputFile.copy(tempFile.path);

      // 4. Image Normalization
      onProgress?.call(0.25, 'Normalizing image...');
      final bytes = await tempFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        throw const ImageProcessError('Failed to decode image. File might be corrupted.');
      }

      // Read EXIF & Bake Orientation
      image = img.bakeOrientation(image);
      
      // Convert to RGB (strip Alpha if problematic, but usually we keep it for PNG)
      // Stripping EXIF happens implicitly when re-encoding with 'image' package

      // 5. Crop Parameter Handling & 6. Crop Execution
      onProgress?.call(0.5, 'Processing crop...');

      // A. Apply Transforms FIRST
      if (rotation != 0) {
        image = img.copyRotate(image, angle: rotation);
      }

      if (flipHorizontal || flipVertical) {
        image = img.flip(
          image,
          direction: flipHorizontal && flipVertical
              ? img.FlipDirection.both
              : flipHorizontal
                  ? img.FlipDirection.horizontal
                  : img.FlipDirection.vertical,
        );
      }

      // B. Apply Crop
      // Pixel mapping with bounds check
      final x = (cropX * image.width).round().clamp(0, image.width - 1);
      final y = (cropY * image.height).round().clamp(0, image.height - 1);
      
      // Prevent upscaling beyond resolution
      final w = (cropWidth * image.width).round().clamp(1, image.width - x);
      final h = (cropHeight * image.height).round().clamp(1, image.height - y);

      image = img.copyCrop(image, x: x, y: y, width: w, height: h);

      // 7. Output Encoding
      onProgress?.call(0.8, 'Encoding image...');
      
      var outputFormat = format;
      if (format == ImageOutputFormat.original) {
        if (ext == 'png') outputFormat = ImageOutputFormat.png;
        else if (ext == 'webp') outputFormat = ImageOutputFormat.webp;
        else outputFormat = ImageOutputFormat.jpg;
      }

      List<int> encodedBytes;
      String outExt;
      switch (outputFormat) {
        case ImageOutputFormat.png:
          encodedBytes = img.encodePng(image);
          outExt = '.png';
          break;
        case ImageOutputFormat.webp:
          // Use standard PNG as fallback if WebP is unsupported in this package version's simple API
          encodedBytes = img.encodePng(image);
          outExt = '.png'; 
          break;
        case ImageOutputFormat.jpg:
        default:
          encodedBytes = img.encodeJpg(image, quality: 85); // Auto-balanced quality
          outExt = '.jpg';
          break;
      }

      // 8. Output Naming Rules
      onProgress?.call(0.9, 'Saving output...');
      final outputDir = await _fileManager.getOutputDir('CropImage');
      
      var cleanName = outputFileName;
      if (cleanName.contains('.')) {
        cleanName = cleanName.substring(0, cleanName.lastIndexOf('.'));
      }

      final outputPath = await _fileManager.generateUniqueOutputPath(
        outputDir,
        cleanName,
        outExt,
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(encodedBytes);

      stopwatch.stop();
      onProgress?.call(1.0, 'Finished!');

      return CropResult(
        outputPath: outputPath,
        outputSizeBytes: encodedBytes.length,
        width: image.width,
        height: image.height,
        duration: stopwatch.elapsed,
      );

    } catch (e) {
      if (e is CropImageError) rethrow;
      throw ImageProcessError('An unexpected error occurred during cropping.', technicalDetail: e.toString());
    } finally {
      // 11. Mandatory Cleanup
      if (tempDir != null) {
        await _fileManager.cleanupToolTemp(_toolId);
      }
    }
  }
}
