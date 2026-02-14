import 'dart:io';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdf_combiner/models/merge_input.dart';
import 'lab_file_manager.dart';

// ─── TYPED ERROR CATEGORIES ─────────────────────────────────────────────────

/// Base class for all merge-related errors.
abstract class MergeError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const MergeError(this.userMessage, [this.technicalDetail]);

  @override
  String toString() => userMessage;
}

/// User picked fewer than 2 files or more than the limit.
class ValidationError extends MergeError {
  const ValidationError(super.userMessage, [super.technicalDetail]);
}

/// Not enough disk space.
class StorageError extends MergeError {
  const StorageError(super.userMessage, [super.technicalDetail]);
}

/// One or more input PDFs are unreadable or corrupted.
class PdfReadError extends MergeError {
  final String fileName;
  const PdfReadError(this.fileName, super.userMessage, [super.technicalDetail]);
}

/// The merge engine itself failed.
class MergeFailedError extends MergeError {
  const MergeFailedError(super.userMessage, [super.technicalDetail]);
}

/// User cancelled the operation.
class CancelledError extends MergeError {
  const CancelledError() : super('Merge cancelled. No files were changed.');
}

// ─── MERGE RESULT ────────────────────────────────────────────────────────────

class MergeResult {
  final String outputPath;
  final int outputSizeBytes;
  final int pagesMerged;
  final Duration duration;

  const MergeResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.pagesMerged,
    required this.duration,
  });
}

// ─── PDF MERGE SERVICE ───────────────────────────────────────────────────────

/// Stateless service that performs the actual PDF merge.
/// All validation, file lifecycle, and cleanup are handled here.
class PdfMergeService {
  static const int minFiles = 2;
  static const int maxFiles = 10;
  static const int maxTotalSizeBytes = 50 * 1024 * 1024; // 50 MB

  final LabFileManager _fileManager;

  PdfMergeService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Validates, merges PDFs, and returns the output path.
  ///
  /// [inputFiles] — user-selected PDF files in desired order
  /// [outputFileName] — desired name for the output (e.g. "merged_file.pdf")
  /// [isCancelled] — callback checked between steps to support cancellation
  /// [onProgress] — reports progress 0.0 → 1.0
  Future<MergeResult> mergePdfs({
    required List<File> inputFiles,
    required String outputFileName,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // ──── Step 1: Validation ─────────────────────────────────────────────
    onProgress?.call(0.0, 'Validating files...');

    if (inputFiles.length < minFiles) {
      throw const ValidationError(
        'Please select at least 2 PDF files to merge.',
      );
    }
    if (inputFiles.length > maxFiles) {
      throw ValidationError(
        'You can merge up to $maxFiles PDFs at a time.',
      );
    }

    // Check each file is readable
    for (final file in inputFiles) {
      if (!await file.exists()) {
        throw PdfReadError(
          _fileName(file),
          '"${_fileName(file)}" could not be found. It may have been moved or deleted.',
        );
      }
      // Basic PDF header check
      try {
        final bytes = await file.openRead(0, 5).first;
        final header = String.fromCharCodes(bytes);
        if (!header.startsWith('%PDF')) {
          throw PdfReadError(
            _fileName(file),
            '"${_fileName(file)}" doesn\'t appear to be a valid PDF file.',
          );
        }
      } catch (e) {
        if (e is PdfReadError) rethrow;
        throw PdfReadError(
          _fileName(file),
          '"${_fileName(file)}" could not be read. It may be corrupted.',
          e.toString(),
        );
      }
    }

    // Check total size
    final totalSize = _fileManager.totalFileSize(inputFiles);
    if (totalSize > maxTotalSizeBytes) {
      throw ValidationError(
        'Total file size (${LabFileManager.formatFileSize(totalSize)}) exceeds the '
        '${LabFileManager.formatFileSize(maxTotalSizeBytes)} limit. Try fewer or smaller files.',
      );
    }

    // Check cancellation after validation
    if (isCancelled?.call() == true) throw const CancelledError();

    // ──── Step 2: Storage check ──────────────────────────────────────────
    onProgress?.call(0.1, 'Checking storage...');

    final hasSpace = await _fileManager.hasEnoughStorage(totalSize);
    if (!hasSpace) {
      throw const StorageError(
        'Not enough storage space on your device. Please free up space and try again.',
      );
    }

    if (isCancelled?.call() == true) throw const CancelledError();

    // ──── Step 3: Prepare output path ────────────────────────────────────
    onProgress?.call(0.15, 'Preparing...');

    final outputDir = await _fileManager.getOutputDir('MergePDF');
    final outputPath = await _fileManager.generateUniqueOutputPath(
      outputDir,
      outputFileName,
      '.pdf',
    );

    if (isCancelled?.call() == true) throw const CancelledError();

    // ──── Step 4: Merge ──────────────────────────────────────────────────
    onProgress?.call(0.2, 'Merging ${inputFiles.length} PDFs...');

    try {
      final inputs = inputFiles
          .map((file) => MergeInput.path(file.path))
          .toList();

      await PdfCombiner.mergeMultiplePDFs(
        inputs: inputs,
        outputPath: outputPath,
      );
    } catch (e) {
      if (e is CancelledError) rethrow;
      // Cleanup any partial output
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      throw MergeFailedError(
        'Couldn\'t merge the PDF files. One of the files may be corrupted or unsupported.',
        e.toString(),
      );
    }

    // Check cancellation and verify output
    if (isCancelled?.call() == true) {
      // Clean up output if cancelled after merge
      final outputFile = File(outputPath);
      if (await outputFile.exists()) await outputFile.delete();
      throw const CancelledError();
    }

    // ──── Step 5: Verify output ──────────────────────────────────────────
    onProgress?.call(0.9, 'Verifying...');

    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      throw const MergeFailedError(
        'The merged file could not be saved. Please try again.',
      );
    }

    final outputSize = await outputFile.length();
    stopwatch.stop();

    onProgress?.call(1.0, 'Done!');

    return MergeResult(
      outputPath: outputPath,
      outputSizeBytes: outputSize,
      pagesMerged: inputFiles.length, // Approximate — one "document" per input
      duration: stopwatch.elapsed,
    );
  }

  String _fileName(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }
}
