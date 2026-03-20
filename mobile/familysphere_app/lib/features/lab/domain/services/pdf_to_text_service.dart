import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'lab_file_manager.dart';

// ─── TYPED ERRORS ────────────────────────────────────────────────────────────

abstract class PdfToTextError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const PdfToTextError(this.userMessage, [this.technicalDetail]);
  @override
  String toString() => userMessage;
}

class PdfReadError extends PdfToTextError {
  const PdfReadError(super.userMessage, [super.technicalDetail]);
}

class TextExtractionError extends PdfToTextError {
  const TextExtractionError(super.userMessage, [super.technicalDetail]);
}

class ExtractionCancelledError extends PdfToTextError {
  const ExtractionCancelledError()
      : super('Text extraction cancelled.');
}

// ─── RESULT ─────────────────────────────────────────────────────────────────

class PdfToTextResult {
  final String outputPath;
  final int outputSizeBytes;
  final int pageCount;
  final int characterCount;
  final String extractedText;
  final Duration duration;

  const PdfToTextResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.pageCount,
    required this.characterCount,
    required this.extractedText,
    required this.duration,
  });
}

// ─── PDF TO TEXT SERVICE ────────────────────────────────────────────────────

class PdfToTextService {
  final LabFileManager _fileManager;

  PdfToTextService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Extracts all text from a PDF file and saves to a .txt file.
  Future<PdfToTextResult> extractText({
    required File inputFile,
    required String outputFileName,
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
    PdfDocument? document;

    try {
      document = PdfDocument(inputBytes: inputBytes);
    } catch (e) {
      throw PdfReadError(
        'Could not open PDF. It may be corrupted or password-protected.',
        e.toString(),
      );
    }

    final int pageCount = document.pages.count;

    if (pageCount == 0) {
      document.dispose();
      throw const PdfReadError('The PDF has no pages.');
    }

    if (isCancelled?.call() == true) {
      document.dispose();
      throw const ExtractionCancelledError();
    }

    try {
      // 2. Extract text from each page
      onProgress?.call(0.2, 'Extracting text...');
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final StringBuffer textBuffer = StringBuffer();

      for (int i = 0; i < pageCount; i++) {
        if (isCancelled?.call() == true) {
          throw const ExtractionCancelledError();
        }

        onProgress?.call(
          0.2 + (0.6 * (i / pageCount)),
          'Extracting page ${i + 1} of $pageCount...',
        );

        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);

        if (i > 0) {
          textBuffer.writeln();
          textBuffer.writeln('--- Page ${i + 1} ---');
          textBuffer.writeln();
        } else {
          textBuffer.writeln('--- Page 1 ---');
          textBuffer.writeln();
        }
        textBuffer.writeln(pageText.trim());
      }

      document.dispose();

      final String extractedText = textBuffer.toString();

      if (extractedText.trim().isEmpty) {
        throw const TextExtractionError(
          'No text could be extracted. The PDF may contain only images.',
        );
      }

      // 3. Save output
      onProgress?.call(0.85, 'Saving text file...');
      final outputDir = await _fileManager.getOutputDir('PdfToText');
      final outputPath = await _fileManager.generateUniqueOutputPath(
        outputDir,
        outputFileName,
        '.txt',
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsString(extractedText);
      final outputSize = await outputFile.length();

      stopwatch.stop();
      onProgress?.call(1.0, 'Done!');

      return PdfToTextResult(
        outputPath: outputPath,
        outputSizeBytes: outputSize,
        pageCount: pageCount,
        characterCount: extractedText.length,
        extractedText: extractedText,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      document.dispose();
      if (e is PdfToTextError) rethrow;
      throw TextExtractionError(
        'An error occurred during text extraction.',
        e.toString(),
      );
    }
  }
}
