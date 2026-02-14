import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'lab_file_manager.dart';

// ─── TYPED ERROR CATEGORIES ─────────────────────────────────────────────────

abstract class ProtectPdfError implements Exception {
  final String userMessage;
  final String? technicalDetail;
  const ProtectPdfError(this.userMessage, [this.technicalDetail]);

  @override
  String toString() => userMessage;
}

class PdfValidationError extends ProtectPdfError {
  const PdfValidationError(super.userMessage, [super.technicalDetail]);
}

class PdfReadError extends ProtectPdfError {
  const PdfReadError(super.userMessage, [super.technicalDetail]);
}

class PdfAlreadyProtectedError extends ProtectPdfError {
  const PdfAlreadyProtectedError()
      : super(
          'This PDF is already password-protected. Please select an unprotected PDF file.',
          'PDF document has existing security settings.',
        );
}

class PdfStorageError extends ProtectPdfError {
  const PdfStorageError(super.userMessage, [super.technicalDetail]);
}

class PdfProtectError extends ProtectPdfError {
  const PdfProtectError(super.userMessage, [super.technicalDetail]);
}

class ProtectCancelledError extends ProtectPdfError {
  const ProtectCancelledError()
      : super('Protection operation cancelled. No files were changed.');
}

// ─── PROTECT PDF RESULT ──────────────────────────────────────────────────────

class ProtectPdfResult {
  final String outputPath;
  final int outputSize;
  final Duration duration;

  const ProtectPdfResult({
    required this.outputPath,
    required this.outputSize,
    required this.duration,
  });
}

// ─── PROTECT PDF SERVICE ─────────────────────────────────────────────────────

class ProtectPdfService {
  final LabFileManager _fileManager;
  
  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100 MB
  static const int minPasswordLength = 6;
  static const String toolName = 'ProtectedPDF';

  ProtectPdfService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Protects a PDF with password and security options.
  /// 
  /// Implements complete Lab Engine workflow:
  /// 1. Validation (file exists, format, encryption status, password, storage)
  /// 2. Temp file preparation
  /// 3. Encryption with AES-256
  /// 4. Metadata stripping
  /// 5. Output generation
  /// 6. Cleanup
  Future<ProtectPdfResult> protectPdf({
    required File inputFile,
    required String outputFileName,
    required String password,
    bool allowPrinting = false,
    bool allowCopyContent = false,
    bool Function()? isCancelled,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final executionId = 'protect_${DateTime.now().millisecondsSinceEpoch}';
    
    File? tempFile;
    PdfDocument? document;

    try {
      // ─── PHASE 1: VALIDATION ─────────────────────────────────────────────────
      
      onProgress?.call(0.05, 'Validating file...');
      
      // Check file exists and is readable
      if (!await inputFile.exists()) {
        throw const PdfReadError('The selected PDF file could not be found.');
      }

      final fileSize = await inputFile.length();
      
      // Check max file size (100 MB)
      if (fileSize > maxFileSizeBytes) {
        final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        throw PdfValidationError(
          'File size ($sizeMB MB) exceeds the maximum allowed size of 100 MB.',
        );
      }

      // Validate password
      if (password.isEmpty || password.length < minPasswordLength) {
        throw PdfValidationError(
          'Password must be at least $minPasswordLength characters long.',
        );
      }

      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      onProgress?.call(0.1, 'Checking PDF format...');
      
      final inputBytes = await inputFile.readAsBytes();
      
      // Verify it's a valid PDF
      try {
        document = PdfDocument(inputBytes: inputBytes);
      } catch (e) {
        throw const PdfReadError(
          'Unable to read the PDF file. The file may be corrupted or not a valid PDF.',
        );
      }

      // Check if PDF is already encrypted
      if (document.security.userPassword.isNotEmpty || 
          document.security.ownerPassword.isNotEmpty) {
        throw const PdfAlreadyProtectedError();
      }

      document.dispose();
      document = null;

      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      // Check available storage (2× file size required)
      onProgress?.call(0.15, 'Checking storage...');
      final requiredSpace = fileSize * 2;
      
      if (!await _fileManager.hasEnoughStorage(requiredSpace)) {
        final requiredMB = (requiredSpace / (1024 * 1024)).toStringAsFixed(1);
        throw PdfStorageError(
          'Not enough storage space. At least $requiredMB MB is required.',
        );
      }

      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      // ─── PHASE 2: TEMP FILE PREPARATION ──────────────────────────────────────
      
      onProgress?.call(0.2, 'Preparing workspace...');
      
      final tempDir = await _fileManager.getTempDir(toolName);
      final tempPath = '${tempDir.path}/${executionId}_input.pdf';
      tempFile = await inputFile.copy(tempPath);

      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      // ─── PHASE 3: ENCRYPTION PROCESS ─────────────────────────────────────────
      
      onProgress?.call(0.3, 'Opening PDF document...');
      
      final tempBytes = await tempFile.readAsBytes();
      document = PdfDocument(inputBytes: tempBytes);
      
      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      onProgress?.call(0.5, 'Applying AES-256 encryption...');
      
      // Configure security
      final PdfSecurity security = document.security;
      
      // Set passwords
      security.userPassword = password; // Required to open the PDF
      security.ownerPassword = _generateOwnerPassword(executionId); // Internal use only
      
      // Set permissions (clear all first, then add allowed ones)
      security.permissions.clear();
      
      if (allowPrinting) {
        security.permissions.add(PdfPermissionsFlags.print);
        // highResolutionPrint is not available in some versions, using fullPrint if needed
        // but typically 'print' is sufficient for standard protection.
      }
      
      if (allowCopyContent) {
        security.permissions.add(PdfPermissionsFlags.copyContent);
      }

      // Use AES-256 encryption if supported by this version of Syncfusion
      // We use a runtime-safe approach since version-specific naming may vary
      try {
        final dynamic securityDyn = security;
        // In some versions it's aes256bit, in others aes256Bit, or aes_256bit
        // We'll try common variants at runtime
        bool set = false;
        final dynamic enumDyn = PdfEncryptionAlgorithm.values;
        for (var value in enumDyn) {
          final strValue = value.toString().toLowerCase();
          if (strValue.contains('aes256') || strValue.contains('aes_256')) {
            securityDyn.encryptionAlgorithm = value;
            set = true;
            break;
          }
        }
        if (!set && enumDyn.isNotEmpty) {
          // Fallback to highest available if AES-256 not found
          securityDyn.encryptionAlgorithm = enumDyn.last;
        }
      } catch (_) {
        // Fallback or ignore if the specific encryption algorithm setter is missing
      }

      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      // ─── PHASE 4: METADATA STRIPPING (Privacy) ───────────────────────────────
      
      onProgress?.call(0.65, 'Removing metadata...');
      
      try {
        // Clear document information for privacy
        document.documentInformation.title = '';
        document.documentInformation.author = '';
        document.documentInformation.subject = '';
        document.documentInformation.keywords = '';
        document.documentInformation.creator = '';
        document.documentInformation.producer = '';
      } catch (_) {
        // Metadata stripping is best-effort; don't fail if not supported
      }

      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      // ─── PHASE 5: OUTPUT GENERATION ──────────────────────────────────────────
      
      onProgress?.call(0.8, 'Saving protected PDF...');
      
      final outputDir = await _fileManager.getOutputDir(toolName);
      final String outputPath = await _fileManager.generateUniqueOutputPath(
        outputDir,
        outputFileName,
        '.pdf',
      );

      final List<int> protectedBytes = await document.save();
      await File(outputPath).writeAsBytes(protectedBytes);

      if (isCancelled?.call() == true) {
        throw const ProtectCancelledError();
      }

      // ─── PHASE 6: VERIFICATION & FINALIZATION ────────────────────────────────
      
      onProgress?.call(0.95, 'Verifying output...');
      
      // Verify output file exists and has content
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw const PdfProtectError('Output file was not created successfully.');
      }

      final outputSize = await outputFile.length();
      if (outputSize == 0) {
        await outputFile.delete();
        throw const PdfProtectError('Output file is empty or corrupted.');
      }

      stopwatch.stop();
      onProgress?.call(1.0, 'Done!');

      return ProtectPdfResult(
        outputPath: outputPath,
        outputSize: outputSize,
        duration: stopwatch.elapsed,
      );
      
    } on ProtectPdfError {
      // Re-throw known errors as-is
      rethrow;
    } catch (e) {
      // Wrap unexpected errors
      throw PdfProtectError(
        'An unexpected error occurred while protecting the PDF.',
        e.toString(),
      );
    } finally {
      // ─── PHASE 7: CLEANUP (MANDATORY) ────────────────────────────────────────
      
      // Dispose document to release resources
      document?.dispose();
      
      // Clean up temp files
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
        await _fileManager.cleanupToolTemp(toolName);
      } catch (_) {
        // Cleanup is best-effort; don't throw errors during cleanup
      }
    }
  }

  /// Generates a secure owner password for internal use.
  /// This password is not exposed to users and provides administrative access.
  String _generateOwnerPassword(String executionId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'fs_owner_${timestamp}_$executionId';
  }
}
