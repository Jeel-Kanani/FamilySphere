import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/unlock_pdf_service.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

enum UnlockStatus {
  idle,
  picking,
  unlocking,
  success,
  error,
}

class SelectedLockedPdf {
  final String name;
  final String path;
  final int sizeBytes;

  const SelectedLockedPdf({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  String get sizeLabel {
    final kb = sizeBytes / 1024;
    final mb = kb / 1024;
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${kb.toStringAsFixed(1)} KB';
  }
}

class UnlockPdfState {
  final SelectedLockedPdf? selectedFile;
  final String password;
  final bool isPasswordVisible;
  final String outputFileName;
  final UnlockStatus status;
  final double progress;
  final String statusLabel;
  final String? errorMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;

  const UnlockPdfState({
    this.selectedFile,
    this.password = '',
    this.isPasswordVisible = false,
    this.outputFileName = '',
    this.status = UnlockStatus.idle,
    this.progress = 0.0,
    this.statusLabel = '',
    this.errorMessage,
    this.outputFilePath,
    this.outputSizeBytes,
  });

  bool get canUnlock =>
      selectedFile != null &&
      password.isNotEmpty &&
      status == UnlockStatus.idle;

  bool get isProcessing =>
      status == UnlockStatus.unlocking ||
      status == UnlockStatus.picking;

  UnlockPdfState copyWith({
    SelectedLockedPdf? selectedFile,
    String? password,
    bool? isPasswordVisible,
    String? outputFileName,
    UnlockStatus? status,
    double? progress,
    String? statusLabel,
    String? errorMessage,
    String? outputFilePath,
    int? outputSizeBytes,
    bool clearSelectedFile = false,
  }) {
    return UnlockPdfState(
      selectedFile: clearSelectedFile ? null : (selectedFile ?? this.selectedFile),
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      outputFileName: outputFileName ?? this.outputFileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusLabel: statusLabel ?? this.statusLabel,
      errorMessage: errorMessage,
      outputFilePath: outputFilePath ?? this.outputFilePath,
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
    );
  }
}

final unlockPdfProvider =
    StateNotifierProvider.autoDispose<UnlockPdfNotifier, UnlockPdfState>((ref) {
  return UnlockPdfNotifier(ref);
});

class UnlockPdfNotifier extends StateNotifier<UnlockPdfState> {
  final Ref _ref;
  final _service = UnlockPdfService();
  bool _isCancelled = false;

  UnlockPdfNotifier(this._ref) : super(const UnlockPdfState());

  Future<void> pickFile() async {
    state = state.copyWith(status: UnlockStatus.picking, errorMessage: null);
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: UnlockStatus.idle);
        return;
      }

      final file = result.files.first;
      state = state.copyWith(
        selectedFile: SelectedLockedPdf(
          name: file.name,
          path: file.path ?? '',
          sizeBytes: file.size,
        ),
        outputFileName: file.name.replaceAll('.pdf', '_unlocked.pdf'),
        status: UnlockStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(
        status: UnlockStatus.error,
        errorMessage: 'Failed to pick file: ${e.toString()}',
      );
    }
  }

  void removeFile() {
    state = state.copyWith(clearSelectedFile: true, status: UnlockStatus.idle);
  }

  void setPassword(String val) => state = state.copyWith(password: val);
  
  void togglePasswordVisibility() => 
      state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);

  void setOutputName(String val) => state = state.copyWith(outputFileName: val);

  void cancel() {
    _isCancelled = true;
    state = state.copyWith(
      statusLabel: 'Cancelling...',
    );
  }

  Future<void> startUnlock() async {
    if (!state.canUnlock) return;

    _isCancelled = false;
    state = state.copyWith(
      status: UnlockStatus.unlocking,
      progress: 0.0,
      statusLabel: 'Initializing...',
      errorMessage: null,
    );

    try {
      final result = await _service.unlockPdf(
        inputFile: File(state.selectedFile!.path),
        outputFileName: state.outputFileName,
        password: state.password,
        isCancelled: () => _isCancelled,
        onProgress: (progress, label) {
          state = state.copyWith(progress: progress, statusLabel: label);
        },
      );

      // Log successful output
      _ref.read(labRecentFilesProvider.notifier).addFile(
            LabRecentFile(
              fileName: state.outputFileName,
              filePath: result.outputPath,
              sizeBytes: result.outputSize,
              toolId: 'unlock_pdf',
              toolLabel: 'Unlock PDF',
              createdAt: DateTime.now(),
            ),
          );

      state = state.copyWith(
        status: UnlockStatus.success,
        outputFilePath: result.outputPath,
        outputSizeBytes: result.outputSize,
        progress: 1.0,
        statusLabel: 'PDF Unlocked Successfully!',
      );
    } on InvalidPasswordError catch (e) {
      state = state.copyWith(
        status: UnlockStatus.error,
        errorMessage: e.userMessage,
      );
    } on PdfNotEncryptedError catch (e) {
      state = state.copyWith(
        status: UnlockStatus.error,
        errorMessage: e.userMessage,
      );
    } on UnlockCancelledError catch (e) {
      state = state.copyWith(
        status: UnlockStatus.idle,
      );
    } on UnlockPdfError catch (e) {
      state = state.copyWith(
        status: UnlockStatus.error,
        errorMessage: e.userMessage,
      );
    } catch (e) {
      state = state.copyWith(
        status: UnlockStatus.error,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  void reset() => state = const UnlockPdfState();
  void dismissError() => state = state.copyWith(status: UnlockStatus.idle);
}
