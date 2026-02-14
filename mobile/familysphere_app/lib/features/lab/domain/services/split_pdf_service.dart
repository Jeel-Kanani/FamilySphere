import 'dart:io';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'lab_file_manager.dart';

// ─── TYPED ERROR CATEGORIES ─────────────────────────────────────────────────

abstract class SplitPdfError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const SplitPdfError(this.userMessage, [this.technicalDetail]);

  @override
  String toString() => userMessage;
}

class PdfValidationError extends SplitPdfError {
  const PdfValidationError(super.userMessage, [super.technicalDetail]);
}

class PdfReadError extends SplitPdfError {
  const PdfReadError(super.userMessage, [super.technicalDetail]);
}

class PdfStorageError extends SplitPdfError {
  const PdfStorageError(super.userMessage, [super.technicalDetail]);
}

class SplittingFailedError extends SplitPdfError {
  const SplittingFailedError(super.userMessage, [super.technicalDetail]);
}

class SplitCancelledError extends SplitPdfError {
  const SplitCancelledError()
      : super('Split operation cancelled. No files were changed.');
}

// ─── SPLIT MODES ────────────────────────────────────────────────────────────

enum SplitMode {
  range,
  individual,
}

// ─── SPLIT RESULT ───────────────────────────────────────────────────────────

class SplitPdfResult {
  final List<String> outputPaths;
  final int totalOutputSize;
  final Duration duration;

  const SplitPdfResult({
    required this.outputPaths,
    required this.totalOutputSize,
    required this.duration,
  });
}

// ─── SPLIT PDF SERVICE ──────────────────────────────────────────────────────

class SplitPdfService {
  final LabFileManager _fileManager;

  SplitPdfService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Splits a PDF based on the mode and range.
  Future<SplitPdfResult> splitPdf({
    required File inputFile,
    required String outputFileName,
    required SplitMode mode,
    String? rangeString,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Validation
    onProgress?.call(0.1, 'Validating file...');
    if (!await inputFile.exists()) {
      throw const PdfReadError('The selected PDF file could not be found.');
    }

    final inputBytes = await inputFile.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: inputBytes);
    final int pageCount = document.pages.count;

    if (pageCount <= 1 && mode == SplitMode.individual) {
      document.dispose();
      throw const PdfValidationError('The PDF already has only one page.');
    }

    if (isCancelled?.call() == true) {
      document.dispose();
      throw const SplitCancelledError();
    }

    final outputDir = await _fileManager.getOutputDir('SplitPDF');
    final List<String> outputPaths = [];
    int totalOutputSize = 0;

    try {
      if (mode == SplitMode.individual) {
        // Individual pages
        for (int i = 0; i < pageCount; i++) {
          if (isCancelled?.call() == true) throw const SplitCancelledError();

          onProgress?.call(0.2 + (0.6 * (i / pageCount)), 'Extracting page ${i + 1} of $pageCount...');

          final PdfDocument newDoc = PdfDocument();
          final PdfPage sourcePage = document.pages[i];
          final PdfTemplate template = sourcePage.createTemplate();
          final PdfPage newPage = newDoc.pages.add();
          newPage.graphics.drawPdfTemplate(template, Offset.zero);
          
          final String baseName = outputFileName.replaceAll('.pdf', '');
          final String pageFileName = '${baseName}_page_${i + 1}.pdf';
          final String outputPath = await _fileManager.generateUniqueOutputPath(
            outputDir,
            pageFileName,
            '.pdf',
          );

          final List<int> bytes = await newDoc.save();
          final File outputFile = File(outputPath);
          await outputFile.writeAsBytes(bytes);
          newDoc.dispose();

          outputPaths.add(outputPath);
          totalOutputSize += bytes.length;
        }
      } else {
        // Range splitting
        onProgress?.call(0.3, 'Processing range...');
        final List<int> pageIndices = _parseRange(rangeString ?? '', pageCount);
        
        if (pageIndices.isEmpty) {
          throw const PdfValidationError('Invalid page range. Please use format like "1-3, 5".');
        }

        final PdfDocument newDoc = PdfDocument();
        for (final index in pageIndices) {
          final PdfPage sourcePage = document.pages[index];
          final PdfTemplate template = sourcePage.createTemplate();
          final PdfPage newPage = newDoc.pages.add();
          newPage.graphics.drawPdfTemplate(template, Offset.zero);
        }

        final String outputPath = await _fileManager.generateUniqueOutputPath(
          outputDir,
          outputFileName,
          '.pdf',
        );

        final List<int> bytes = await newDoc.save();
        await File(outputPath).writeAsBytes(bytes);
        newDoc.dispose();

        outputPaths.add(outputPath);
        totalOutputSize = bytes.length;
      }
    } catch (e) {
      if (e is SplitPdfError) rethrow;
      throw SplittingFailedError('Extraction failed', e.toString());
    } finally {
      document.dispose();
    }

    stopwatch.stop();
    onProgress?.call(1.0, 'Done!');

    return SplitPdfResult(
      outputPaths: outputPaths,
      totalOutputSize: totalOutputSize,
      duration: stopwatch.elapsed,
    );
  }

  /// Parses range string like "1-3, 5, 8-10" into list of 0-based indices.
  List<int> _parseRange(String range, int maxPages) {
    if (range.trim().isEmpty) return [];
    
    final List<int> indices = [];
    final parts = range.split(RegExp(r'[,\s]+'));

    for (final part in parts) {
      if (part.contains('-')) {
        final bounds = part.split('-');
        if (bounds.length == 2) {
          final start = int.tryParse(bounds[0].trim());
          final end = int.tryParse(bounds[1].trim());
          if (start != null && end != null && start > 0 && end >= start) {
            for (int i = start; i <= end && i <= maxPages; i++) {
              if (!indices.contains(i - 1)) indices.add(i - 1);
            }
          }
        }
      } else {
        final page = int.tryParse(part.trim());
        if (page != null && page > 0 && page <= maxPages) {
          if (!indices.contains(page - 1)) indices.add(page - 1);
        }
      }
    }
    
    indices.sort();
    return indices;
  }
}
