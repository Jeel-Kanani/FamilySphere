import 'dart:io';
import 'package:image/image.dart' as img;
import 'lab_file_manager.dart';

// ─── TYPED ERRORS ────────────────────────────────────────────────────────────

abstract class BgRemoverError implements Exception {
  final String userMessage;
  const BgRemoverError(this.userMessage);
  @override
  String toString() => userMessage;
}

class BgLoadError extends BgRemoverError {
  const BgLoadError(super.userMessage);
}

class BgProcessError extends BgRemoverError {
  const BgProcessError(super.userMessage);
}

// ─── RESULT ─────────────────────────────────────────────────────────────────

class BgRemoverResult {
  final String outputPath;
  final int outputSizeBytes;
  final int width;
  final int height;
  final int pixelsRemoved;
  final Duration duration;

  const BgRemoverResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
    required this.pixelsRemoved,
    required this.duration,
  });
}

// ─── BG REMOVER SERVICE ─────────────────────────────────────────────────────

class BgRemoverService {
  final LabFileManager _fileManager;

  BgRemoverService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Removes solid-color backgrounds by replacing near-white/light pixels
  /// with transparency. This is color-threshold based, not AI segmentation.
  Future<BgRemoverResult> removeBackground({
    required File inputFile,
    required String outputFileName,
    int tolerance = 30,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Load
    onProgress?.call(0.1, 'Loading image...');
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const BgLoadError('Could not decode image.');
    }

    // 2. Sample corner pixels to determine background color
    onProgress?.call(0.2, 'Detecting background...');
    final bgColor = _detectBackgroundColor(image);

    // 3. Replace matching pixels with transparency
    onProgress?.call(0.3, 'Removing background...');
    int pixelsRemoved = 0;
    final totalPixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      if (y % 50 == 0) {
        onProgress?.call(0.3 + 0.5 * (y / image.height), 'Processing row ${y + 1}...');
      }
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        if (_isColorMatch(r, g, b, bgColor, tolerance)) {
          image.setPixelRgba(x, y, 0, 0, 0, 0);
          pixelsRemoved++;
        }
      }
    }

    if (pixelsRemoved == 0) {
      throw const BgProcessError(
        'No background pixels detected. Try increasing the tolerance.',
      );
    }

    // 4. Save as PNG (supports transparency)
    onProgress?.call(0.85, 'Saving...');
    final encoded = img.encodePng(image);

    final outputDir = await _fileManager.getOutputDir('BgRemover');
    var baseName = outputFileName;
    if (baseName.contains('.')) {
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }

    final outputPath = await _fileManager.generateUniqueOutputPath(
      outputDir, baseName, '.png',
    );

    await File(outputPath).writeAsBytes(encoded);

    stopwatch.stop();
    onProgress?.call(1.0, 'Done!');

    return BgRemoverResult(
      outputPath: outputPath,
      outputSizeBytes: encoded.length,
      width: image.width,
      height: image.height,
      pixelsRemoved: pixelsRemoved,
      duration: stopwatch.elapsed,
    );
  }

  /// Detects the most likely background color by sampling corner pixels.
  List<int> _detectBackgroundColor(img.Image image) {
    final corners = <img.Pixel>[];
    // Sample from all 4 corners (a few pixels each)
    for (int dy = 0; dy < 3; dy++) {
      for (int dx = 0; dx < 3; dx++) {
        corners.add(image.getPixel(dx, dy)); // top-left
        corners.add(image.getPixel(image.width - 1 - dx, dy)); // top-right
        corners.add(image.getPixel(dx, image.height - 1 - dy)); // bottom-left
        corners.add(image.getPixel(image.width - 1 - dx, image.height - 1 - dy)); // bottom-right
      }
    }

    // Average the corner colors
    int rSum = 0, gSum = 0, bSum = 0;
    for (final p in corners) {
      rSum += p.r.toInt();
      gSum += p.g.toInt();
      bSum += p.b.toInt();
    }
    final count = corners.length;
    return [rSum ~/ count, gSum ~/ count, bSum ~/ count];
  }

  bool _isColorMatch(int r, int g, int b, List<int> bgColor, int tolerance) {
    return (r - bgColor[0]).abs() <= tolerance &&
        (g - bgColor[1]).abs() <= tolerance &&
        (b - bgColor[2]).abs() <= tolerance;
  }
}
