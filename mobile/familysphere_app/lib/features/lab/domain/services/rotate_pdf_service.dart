import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'lab_file_manager.dart';

// ─── TYPED ERRORS ────────────────────────────────────────────────────────────

abstract class RotatePdfError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const RotatePdfError(this.userMessage, [this.technicalDetail]);
  @override
  String toString() => userMessage;
}

class PdfLoadError extends RotatePdfError {
  const PdfLoadError(super.userMessage, [super.technicalDetail]);
}

class RotateProcessError extends RotatePdfError {
  const RotateProcessError(super.userMessage, [super.technicalDetail]);
}

class RotateCancelledError extends RotatePdfError {
  const RotateCancelledError()
      : super('Rotation cancelled. No files were changed.');
}

// ─── ROTATION ANGLE ─────────────────────────────────────────────────────────

enum RotationAngle {
  rotate90('90°', PdfPageRotateAngle.rotateAngle90),
  rotate180('180°', PdfPageRotateAngle.rotateAngle180),
  rotate270('270°', PdfPageRotateAngle.rotateAngle270);

  final String label;
  final PdfPageRotateAngle pdfAngle;
  const RotationAngle(this.label, this.pdfAngle);
}

// ─── RESULT ─────────────────────────────────────────────────────────────────

class RotatePdfResult {
  final String outputPath;
  final int outputSizeBytes;
  final int pageCount;
  final Duration duration;

  const RotatePdfResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.pageCount,
    required this.duration,
  });
}

// ─── ROTATE PDF SERVICE ─────────────────────────────────────────────────────

class RotatePdfService {
  final LabFileManager _fileManager;

  RotatePdfService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Rotates all pages in a PDF by the specified angle.
  Future<RotatePdfResult> rotatePdf({
    required File inputFile,
    required String outputFileName,
    required RotationAngle angle,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Validation
    onProgress?.call(0.1, 'Validating file...');
    if (!await inputFile.exists()) {
      throw const PdfLoadError('The selected PDF file could not be found.');
    }

    final inputBytes = await inputFile.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: inputBytes);
    final int pageCount = document.pages.count;

    if (pageCount == 0) {
      document.dispose();
      throw const PdfLoadError('The PDF has no pages to rotate.');
    }

    if (isCancelled?.call() == true) {
      document.dispose();
      throw const RotateCancelledError();
    }

    try {
      // 2. Rotate each page in-place using PdfPage.rotation
      onProgress?.call(0.2, 'Rotating pages...');

      for (int i = 0; i < pageCount; i++) {
        if (isCancelled?.call() == true) {
          document.dispose();
          throw const RotateCancelledError();
        }

        onProgress?.call(
          0.2 + (0.6 * (i / pageCount)),
          'Rotating page ${i + 1} of $pageCount...',
        );

        // Apply rotation directly via the page's rotation property
        document.pages[i].rotation = angle.pdfAngle;
      }

      // 3. Save output
      onProgress?.call(0.85, 'Saving rotated PDF...');
      final outputDir = await _fileManager.getOutputDir('RotatePDF');
      final outputPath = await _fileManager.generateUniqueOutputPath(
        outputDir,
        outputFileName,
        '.pdf',
      );

      final List<int> bytes = await document.save();
      await File(outputPath).writeAsBytes(bytes);
      document.dispose();

      stopwatch.stop();
      onProgress?.call(1.0, 'Done!');

      return RotatePdfResult(
        outputPath: outputPath,
        outputSizeBytes: bytes.length,
        pageCount: pageCount,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      document.dispose();
      if (e is RotatePdfError) rethrow;
      throw RotateProcessError(
        'An error occurred while rotating the PDF.',
        e.toString(),
      );
    }
  }
}
