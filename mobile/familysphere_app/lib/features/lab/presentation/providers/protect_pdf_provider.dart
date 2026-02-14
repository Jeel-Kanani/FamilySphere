import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:familysphere_app/features/lab/domain/services/protect_pdf_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── STATE ───────────────────────────────────────────────────────────────────

enum ProtectStatus {
  idle,
  picking,
  protecting,
  success,
  error,
}

class SelectedPdfFile {
  final String name;
  final String path;
  final int sizeBytes;
  final int pageCount;

  const SelectedPdfFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.pageCount,
  });

  String get sizeLabel => LabFileManager.formatFileSize(sizeBytes);
}

class ProtectPdfState {
  final SelectedPdfFile? selectedFile;
  final String password;
  final String confirmPassword;
  final bool allowPrinting;
  final bool allowCopyContent;
  final String outputFileName;
  final ProtectStatus status;
  final double progress;
  final String progressMessage;
  final String? errorMessage;
  final String? outputFilePath;

  const ProtectPdfState({
    this.selectedFile,
    this.password = '',
    this.confirmPassword = '',
    this.allowPrinting = false,
    this.allowCopyContent = false,
    this.outputFileName = 'protected_document.pdf',
    this.status = ProtectStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.errorMessage,
    this.outputFilePath,
  });

  bool get canProtect =>
      selectedFile != null &&
      password.isNotEmpty &&
      password == confirmPassword &&
      password.length >= 6 &&
      status == ProtectStatus.idle;

  bool get isProcessing =>
      status == ProtectStatus.protecting ||
      status == ProtectStatus.picking;

  int get passwordStrength {
    if (password.isEmpty) return 0;
    if (password.length < 6) return 1;
    if (password.length < 10) return 2;
    // Basic check for variety
    bool hasLetters = password.contains(RegExp(r'[a-zA-Z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    int variety = (hasLetters ? 1 : 0) + (hasNumbers ? 1 : 0) + (hasSpecial ? 1 : 0);
    if (password.length >= 12 && variety >= 3) return 4;
    if (variety >= 2) return 3;
    return 2;
  }

  String get strengthLabel {
    switch (passwordStrength) {
      case 0: return 'None';
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Strong';
      default: return 'None';
    }
  }

  ProtectPdfState copyWith({
    SelectedPdfFile? selectedFile,
    String? password,
    String? confirmPassword,
    bool? allowPrinting,
    bool? allowCopyContent,
    String? outputFileName,
    ProtectStatus? status,
    double? progress,
    String? progressMessage,
    String? errorMessage,
    String? outputFilePath,
    bool clearSelectedFile = false,
  }) {
    return ProtectPdfState(
      selectedFile: clearSelectedFile ? null : (selectedFile ?? this.selectedFile),
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      allowPrinting: allowPrinting ?? this.allowPrinting,
      allowCopyContent: allowCopyContent ?? this.allowCopyContent,
      outputFileName: outputFileName ?? this.outputFileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      errorMessage: errorMessage,
      outputFilePath: outputFilePath ?? this.outputFilePath,
    );
  }
}

// ─── PROVIDER ────────────────────────────────────────────────────────────────

final protectPdfProvider =
    StateNotifierProvider.autoDispose<ProtectPdfNotifier, ProtectPdfState>((ref) {
  return ProtectPdfNotifier(ref);
});

class ProtectPdfNotifier extends StateNotifier<ProtectPdfState> {
  ProtectPdfNotifier(this._ref) : super(const ProtectPdfState());

  final Ref _ref;
  final ProtectPdfService _protectService = ProtectPdfService();
  final LabFileManager _fileManager = LabFileManager();
  bool _isCancelled = false;

  /// Opens file picker to select a single PDF.
  Future<void> pickFile() async {
    if (state.isProcessing) return;

    state = state.copyWith(status: ProtectStatus.picking);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        state = state.copyWith(status: ProtectStatus.idle);
        return;
      }

      final platformFile = result.files.first;
      final file = File(platformFile.path!);
      
      // Extract page count
      final bytes = await file.readAsBytes();
      PdfDocument? document;
      int pageCount = 0;
      bool isAlreadyProtected = false;
      
      try {
        document = PdfDocument(inputBytes: bytes);
        pageCount = document.pages.count;
        
        // Check if PDF is already protected
        if (document.security.userPassword.isNotEmpty || 
            document.security.ownerPassword.isNotEmpty) {
          isAlreadyProtected = true;
        }
      } catch (e) {
        state = state.copyWith(
          status: ProtectStatus.error,
          errorMessage: 'Unable to read PDF file. It may be corrupted.',
        );
        return;
      } finally {
        document?.dispose();
      }

      // If already protected, show error immediately
      if (isAlreadyProtected) {
        state = state.copyWith(
          status: ProtectStatus.error,
          errorMessage: 'This PDF is already password-protected. Please select an unprotected PDF.',
        );
        return;
      }

      state = state.copyWith(
        selectedFile: SelectedPdfFile(
          name: platformFile.name,
          path: platformFile.path!,
          sizeBytes: platformFile.size,
          pageCount: pageCount,
        ),
        status: ProtectStatus.idle,
        outputFileName: '${platformFile.name.replaceAll('.pdf', '')}_protected.pdf',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProtectStatus.error,
        errorMessage: 'Could not open file picker.',
      );
    }
  }

  void removeFile() {
    if (state.isProcessing) return;
    state = state.copyWith(clearSelectedFile: true, status: ProtectStatus.idle);
  }

  void setPassword(String val) => state = state.copyWith(password: val);
  void setConfirmPassword(String val) => state = state.copyWith(confirmPassword: val);
  void togglePrinting(bool val) => state = state.copyWith(allowPrinting: val);
  void toggleCopying(bool val) => state = state.copyWith(allowCopyContent: val);
  void setOutputName(String val) => state = state.copyWith(outputFileName: val);

  Future<void> startProtect() async {
    if (!state.canProtect) return;

    _isCancelled = false;
    state = state.copyWith(
      status: ProtectStatus.protecting,
      progress: 0.0,
      progressMessage: 'Starting...',
    );

    try {
      final inputFile = File(state.selectedFile!.path);
      
      final result = await _protectService.protectPdf(
        inputFile: inputFile,
        outputFileName: state.outputFileName,
        password: state.password,
        allowPrinting: state.allowPrinting,
        allowCopyContent: state.allowCopyContent,
        isCancelled: () => _isCancelled,
        onProgress: (progress, statusMsg) {
          if (!mounted) return;
          state = state.copyWith(
            progress: progress,
            progressMessage: statusMsg,
          );
        },
      );

      if (!mounted) return;

      // Add to recent files
      _ref.read(labRecentFilesProvider.notifier).addFile(
        LabRecentFile(
          filePath: result.outputPath,
          fileName: state.outputFileName,
          sizeBytes: result.outputSize,
          toolId: 'protect_pdf',
          toolLabel: 'Protect PDF',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        status: ProtectStatus.success,
        progress: 1.0,
        progressMessage: 'Done!',
        outputFilePath: result.outputPath,
      );
    } on ProtectCancelledError {
      await _fileManager.cleanupToolTemp('ProtectedPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ProtectStatus.idle,
        errorMessage: 'Operation cancelled.',
      );
    } on PdfAlreadyProtectedError catch (e) {
      await _fileManager.cleanupToolTemp('ProtectedPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ProtectStatus.error,
        errorMessage: e.userMessage,
      );
    } on PdfStorageError catch (e) {
      await _fileManager.cleanupToolTemp('ProtectedPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ProtectStatus.error,
        errorMessage: e.userMessage,
      );
    } on PdfValidationError catch (e) {
      await _fileManager.cleanupToolTemp('ProtectedPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ProtectStatus.error,
        errorMessage: e.userMessage,
      );
    } on ProtectPdfError catch (e) {
      await _fileManager.cleanupToolTemp('ProtectedPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ProtectStatus.error,
        errorMessage: e.userMessage,
      );
    } catch (e) {
      await _fileManager.cleanupToolTemp('ProtectedPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ProtectStatus.error,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  void cancelProtect() {
    _isCancelled = true;
  }

  void reset() {
    state = const ProtectPdfState();
  }

  void dismissError() {
    state = state.copyWith(status: ProtectStatus.idle);
  }
}
