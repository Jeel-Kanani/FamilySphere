import 'dart:io';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdf_combiner/models/merge_input.dart';
import 'package:pdf_combiner/models/pdf_from_multiple_image_config.dart';
import 'package:pdf_combiner/models/image_scale.dart';
import 'lab_file_manager.dart';

// ─── TYPED ERROR CATEGORIES ─────────────────────────────────────────────────

/// Base class for all image-to-PDF errors.
abstract class ImageToPdfError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const ImageToPdfError(this.userMessage, [this.technicalDetail]);

  @override
  String toString() => userMessage;
}

/// Input validation failed (count, size, format).
class ImageValidationError extends ImageToPdfError {
  const ImageValidationError(super.userMessage, [super.technicalDetail]);
}

/// An image file is unreadable or corrupted.
class ImageReadError extends ImageToPdfError {
  final String fileName;
  const ImageReadError(this.fileName, super.userMessage, [super.technicalDetail]);
}

/// Not enough disk space.
class ImageStorageError extends ImageToPdfError {
  const ImageStorageError(super.userMessage, [super.technicalDetail]);
}

/// The PDF generation engine itself failed.
class ConversionFailedError extends ImageToPdfError {
  const ConversionFailedError(super.userMessage, [super.technicalDetail]);
}

/// User cancelled the operation.
class ConversionCancelledError extends ImageToPdfError {
  const ConversionCancelledError()
      : super('Conversion cancelled. No files were changed.');
}

// ─── PAGE SIZE & ORIENTATION ────────────────────────────────────────────────

/// Supported page sizes with their dimensions at 300 DPI.
/// Using 300 DPI provides print-quality output (industry standard).
/// (150 DPI is adequate for screen viewing, 300 DPI is ideal for printing.)
enum PdfPageSize {
  auto('Auto (Fit Image)'),
  a4('A4 (210 × 297 mm)'),
  a3('A3 (297 × 420 mm)'),
  a5('A5 (148 × 210 mm)'),
  letter('Letter (8.5 × 11 in)'),
  legal('Legal (8.5 × 14 in)'),
  b5('B5 (176 × 250 mm)'),
  postcard('Postcard (4 × 6 in)');

  final String label;
  const PdfPageSize(this.label);

  /// Returns pixel dimensions at 300 DPI in portrait orientation [width, height].
  /// Returns null for 'auto' (use original image size).
  ({int width, int height})? get portraitPixels {
    const dpi = 300;
    switch (this) {
      case PdfPageSize.auto:
        return null;
      case PdfPageSize.a4:
        // 210mm × 297mm → 8.27in × 11.69in
        return (width: (8.27 * dpi).round(), height: (11.69 * dpi).round());
      case PdfPageSize.a3:
        // 297mm × 420mm → 11.69in × 16.54in
        return (width: (11.69 * dpi).round(), height: (16.54 * dpi).round());
      case PdfPageSize.a5:
        // 148mm × 210mm → 5.83in × 8.27in
        return (width: (5.83 * dpi).round(), height: (8.27 * dpi).round());
      case PdfPageSize.letter:
        // 8.5in × 11in
        return (width: (8.5 * dpi).round(), height: (11.0 * dpi).round());
      case PdfPageSize.legal:
        // 8.5in × 14in
        return (width: (8.5 * dpi).round(), height: (14.0 * dpi).round());
      case PdfPageSize.b5:
        // 176mm × 250mm → 6.93in × 9.84in
        return (width: (6.93 * dpi).round(), height: (9.84 * dpi).round());
      case PdfPageSize.postcard:
        // 4in × 6in
        return (width: (4.0 * dpi).round(), height: (6.0 * dpi).round());
    }
  }
}

enum PdfOrientation {
  auto('Auto (Match Image)'),
  portrait('Portrait'),
  landscape('Landscape');

  final String label;
  const PdfOrientation(this.label);
}

// ─── CONVERSION RESULT ──────────────────────────────────────────────────────

class ImageToPdfResult {
  final String outputPath;
  final int outputSizeBytes;
  final int pageCount;
  final Duration duration;

  const ImageToPdfResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.pageCount,
    required this.duration,
  });
}

// ─── IMAGE TO PDF SERVICE ───────────────────────────────────────────────────

/// Stateless service that converts images into a multi-page PDF.
/// All validation, file lifecycle, and cleanup are handled here.
class ImageToPdfService {
  static const int minImages = 1;
  static const int maxImages = 30;
  static const int maxTotalSizeBytes = 100 * 1024 * 1024; // 100 MB

  static const List<String> supportedExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'heic',
  ];

  final LabFileManager _fileManager;

  ImageToPdfService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Builds the [PdfFromMultipleImageConfig] based on user-selected
  /// page size and orientation.
  PdfFromMultipleImageConfig _buildConfig(
    PdfPageSize pageSize,
    PdfOrientation orientation,
  ) {
    final dims = pageSize.portraitPixels;

    // Auto mode: no rescaling, keep original image dimensions
    if (dims == null) {
      return const PdfFromMultipleImageConfig(
        rescale: ImageScale.original,
        keepAspectRatio: true,
      );
    }

    int width = dims.width;
    int height = dims.height;

    // Apply orientation
    if (orientation == PdfOrientation.landscape) {
      // Swap to landscape
      final temp = width;
      width = height;
      height = temp;
    }
    // For PdfOrientation.auto, we keep portrait dimensions
    // (the library will keep aspect ratio and fit within the box)

    return PdfFromMultipleImageConfig(
      rescale: ImageScale(width: width, height: height),
      keepAspectRatio: true,
    );
  }

  /// Converts a list of images into a single PDF.
  ///
  /// [inputImages] — user-selected image files in desired page order
  /// [outputFileName] — desired name for the output (e.g. "images_to_pdf.pdf")
  /// [pageSize] — page size for PDF pages
  /// [orientation] — page orientation
  /// [isCancelled] — callback checked between steps to support cancellation
  /// [onProgress] — reports progress 0.0 → 1.0
  Future<ImageToPdfResult> convertImagesToPdf({
    required List<File> inputImages,
    required String outputFileName,
    PdfPageSize pageSize = PdfPageSize.auto,
    PdfOrientation orientation = PdfOrientation.auto,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // ──── Step 1: Validation ─────────────────────────────────────────────
    onProgress?.call(0.0, 'Validating images...');

    if (inputImages.isEmpty) {
      throw const ImageValidationError(
        'Please select at least 1 image to convert.',
      );
    }
    if (inputImages.length > maxImages) {
      throw ImageValidationError(
        'You can convert up to $maxImages images at a time.',
      );
    }

    // Check each file
    for (final file in inputImages) {
      if (!await file.exists()) {
        throw ImageReadError(
          _fileName(file),
          '"${_fileName(file)}" could not be found. It may have been moved or deleted.',
        );
      }

      // Verify extension
      final ext = _fileExtension(file).toLowerCase();
      if (!supportedExtensions.contains(ext)) {
        throw ImageReadError(
          _fileName(file),
          '"${_fileName(file)}" is not a supported image format. Use JPG, PNG, or WEBP.',
        );
      }
    }

    // Check total size
    final totalSize = _fileManager.totalFileSize(inputImages);
    if (totalSize > maxTotalSizeBytes) {
      throw ImageValidationError(
        'Total file size (${LabFileManager.formatFileSize(totalSize)}) exceeds the '
        '${LabFileManager.formatFileSize(maxTotalSizeBytes)} limit. Try fewer or smaller images.',
      );
    }

    if (isCancelled?.call() == true) throw const ConversionCancelledError();

    // ──── Step 2: Storage check ──────────────────────────────────────────
    onProgress?.call(0.1, 'Checking storage...');

    final hasSpace = await _fileManager.hasEnoughStorage(totalSize);
    if (!hasSpace) {
      throw const ImageStorageError(
        'Not enough storage space on your device. Please free up space and try again.',
      );
    }

    if (isCancelled?.call() == true) throw const ConversionCancelledError();

    // ──── Step 3: Prepare output path ────────────────────────────────────
    onProgress?.call(0.15, 'Preparing...');

    final outputDir = await _fileManager.getOutputDir('ImageToPDF');
    final outputPath = await _fileManager.generateUniqueOutputPath(
      outputDir,
      outputFileName,
      '.pdf',
    );

    if (isCancelled?.call() == true) throw const ConversionCancelledError();

    // ──── Step 4: Convert images to PDF ──────────────────────────────────
    onProgress?.call(0.2, 'Creating PDF from ${inputImages.length} images...');

    try {
      final inputs = inputImages
          .map((file) => MergeInput.path(file.path))
          .toList();

      final config = _buildConfig(pageSize, orientation);

      await PdfCombiner.createPDFFromMultipleImages(
        inputs: inputs,
        outputPath: outputPath,
        config: config,
      );
    } catch (e) {
      if (e is ConversionCancelledError) rethrow;
      // Cleanup any partial output
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      throw ConversionFailedError(
        'Couldn\'t create the PDF. One of the images may be corrupted or unsupported.',
        e.toString(),
      );
    }

    // Check cancellation after conversion
    if (isCancelled?.call() == true) {
      final outputFile = File(outputPath);
      if (await outputFile.exists()) await outputFile.delete();
      throw const ConversionCancelledError();
    }

    // ──── Step 5: Verify output ──────────────────────────────────────────
    onProgress?.call(0.9, 'Verifying...');

    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      throw const ConversionFailedError(
        'The PDF file could not be saved. Please try again.',
      );
    }

    final outputSize = await outputFile.length();
    stopwatch.stop();

    onProgress?.call(1.0, 'Done!');

    return ImageToPdfResult(
      outputPath: outputPath,
      outputSizeBytes: outputSize,
      pageCount: inputImages.length,
      duration: stopwatch.elapsed,
    );
  }

  String _fileName(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  String _fileExtension(File file) {
    final name = _fileName(file);
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0) return '';
    return name.substring(dotIndex + 1);
  }
}
