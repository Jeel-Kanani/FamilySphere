import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'lab_file_manager.dart';

// ─── TYPED ERROR CATEGORIES ─────────────────────────────────────────────────

abstract class UnlockPdfError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const UnlockPdfError(this.userMessage, [this.technicalDetail]);

  @override
  String toString() => userMessage;
}

class PdfValidationError extends UnlockPdfError {
  const PdfValidationError(super.userMessage, [super.technicalDetail]);
}

class PdfReadError extends UnlockPdfError {
  const PdfReadError(super.userMessage, [super.technicalDetail]);
}

class PdfNotEncryptedError extends UnlockPdfError {
  const PdfNotEncryptedError(super.userMessage);
}

class InvalidPasswordError extends UnlockPdfError {
  const InvalidPasswordError(super.userMessage);
}

class PdfStorageError extends UnlockPdfError {
  const PdfStorageError(super.userMessage, [super.technicalDetail]);
}

class UnlockFailedError extends UnlockPdfError {
  const UnlockFailedError(super.userMessage, [super.technicalDetail]);
}

class UnlockCancelledError extends UnlockPdfError {
  const UnlockCancelledError()
      : super('Unlock operation cancelled. No files were changed.');
}

// ─── UNLOCK RESULT ──────────────────────────────────────────────────────────

class UnlockPdfResult {
  final String outputPath;
  final int outputSize;
  final Duration duration;

  const UnlockPdfResult({
    required this.outputPath,
    required this.outputSize,
    required this.duration,
  });
}

// ─── UNLOCK PDF SERVICE ──────────────────────────────────────────────────────

class UnlockPdfService {
  final LabFileManager _fileManager;

  UnlockPdfService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Unlocks a password-protected PDF by importing pages into a fresh document.
  Future<UnlockPdfResult> unlockPdf({
    required File inputFile,
    required String outputFileName,
    required String password,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    // ─── PHASE 1: VALIDATION ─────────────────────────────────────────────────
    onProgress?.call(0.05, 'Validating file...');
    
    if (!await inputFile.exists()) {
      throw const PdfReadError('The selected PDF file could not be found.');
    }

    if (password.isEmpty) {
      throw const PdfValidationError('Password cannot be empty.');
    }

    final int inputSize = await inputFile.length();
    final bool hasSpace = await _fileManager.hasEnoughStorage(inputSize * 2);
    if (!hasSpace) {
      throw const PdfStorageError('Insufficient storage to unlock this PDF. Please free up some space.');
    }

    if (isCancelled?.call() == true) throw const UnlockCancelledError();

    // ─── PHASE 2: INITIALIZATION ───────────────────────────────────────────
    onProgress?.call(0.1, 'Initializing workspace...');
    final String executionId = DateTime.now().millisecondsSinceEpoch.toString();
    final Directory tempDir = await _fileManager.getTempDir('UnlockPDF_$executionId');
    final Directory outputDir = await _fileManager.getOutputDir('UnlockPDF');

    try {
      final Uint8List inputBytes = await inputFile.readAsBytes();
      
      // ─── PHASE 3: ENCRYPTION CHECK & PASSWORD VERIFICATION ───────────────
      onProgress?.call(0.2, 'Verifying password...');
      
      PdfDocument? loadedDocument;
      try {
        // First try without password to check if it's actually encrypted
        try {
          final PdfDocument check = PdfDocument(inputBytes: inputBytes);
          check.dispose();
          throw const PdfNotEncryptedError('This PDF is not password-protected. It can be opened without a password.');
        } catch (e) {
          if (e is PdfNotEncryptedError) rethrow;
          // Expected failure for encrypted files
        }

        // Now try with the password
        loadedDocument = PdfDocument(inputBytes: inputBytes, password: password);
      } catch (e) {
        if (e is PdfNotEncryptedError) rethrow;
        throw const InvalidPasswordError('Incorrect password. Please check and try again.');
      }

      if (isCancelled?.call() == true) {
        loadedDocument.dispose();
        throw const UnlockCancelledError();
      }

      // ─── PHASE 5: UNLOCKING (IMPORT METHOD) ──────────────────────────────
      onProgress?.call(0.4, 'Creating unlocked copy...');
      
      final PdfDocument outputDocument = PdfDocument();
      
      try {
        final int pageCount = loadedDocument.pages.count;
        for (int i = 0; i < pageCount; i++) {
          if (isCancelled?.call() == true) throw const UnlockCancelledError();
          
          final progress = 0.4 + (0.4 * (i / pageCount));
          onProgress?.call(progress, 'Processing page ${i + 1} of $pageCount...');
          
          final PdfPage sourcePage = loadedDocument.pages[i];
          final Size size = sourcePage.size;
          
          // Add page with exact original dimensions
          final PdfPage newPage = outputDocument.pages.add();
          // We set margins to zero and size to match source
          outputDocument.pageSettings.margins.all = 0;
          outputDocument.pageSettings.size = size;
          
          // Draw content from source to new page
          newPage.graphics.drawPdfTemplate(
            sourcePage.createTemplate(),
            Offset.zero,
            size,
          );
        }

        // ─── PHASE 6: PRIVACY ──────────────────────────────────────────────
        onProgress?.call(0.85, 'Stripping metadata...');
        outputDocument.documentInformation.author = '';
        outputDocument.documentInformation.creator = '';
        outputDocument.documentInformation.producer = 'FamilySphere Lab';
        outputDocument.documentInformation.subject = '';
        outputDocument.documentInformation.title = '';
        outputDocument.documentInformation.keywords = '';

        // ─── PHASE 7: OUTPUT GENERATION ────────────────────────────────────
        onProgress?.call(0.9, 'Saving output...');
        
        final String outputPath = await _fileManager.generateUniqueOutputPath(
          outputDir,
          outputFileName,
          '.pdf',
        );

        final List<int> bytes = await outputDocument.save();
        await File(outputPath).writeAsBytes(bytes);
        
        onProgress?.call(0.95, 'Finalizing...');
        
        stopwatch.stop();
        return UnlockPdfResult(
          outputPath: outputPath,
          outputSize: bytes.length,
          duration: stopwatch.elapsed,
        );
      } finally {
        loadedDocument.dispose();
        outputDocument.dispose();
      }
    } catch (e) {
      if (e is UnlockPdfError) rethrow;
      throw UnlockFailedError('Processing failed: ${e.toString()}');
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}
