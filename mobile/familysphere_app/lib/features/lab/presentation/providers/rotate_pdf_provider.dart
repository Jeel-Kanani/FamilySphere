import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/rotate_pdf_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── STATE ──────────────────────────────────────────────────────────────────

enum RotateStatus { idle, picking, ready, processing, success, error }

class RotatePdfState {
  final File? inputFile;
  final String? inputFileName;
  final int inputSizeBytes;
  final RotationAngle angle;
  final RotateStatus status;
  final double progress;
  final String progressMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;
  final int? pageCount;
  final String? errorMessage;

  const RotatePdfState({
    this.inputFile,
    this.inputFileName,
    this.inputSizeBytes = 0,
    this.angle = RotationAngle.rotate90,
    this.status = RotateStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.outputFilePath,
    this.outputSizeBytes,
    this.pageCount,
    this.errorMessage,
  });

  bool get isProcessing => status == RotateStatus.picking || status == RotateStatus.processing;
  bool get canProcess => status == RotateStatus.ready && inputFile != null;

  RotatePdfState copyWith({
    File? inputFile,
    String? inputFileName,
    int? inputSizeBytes,
    RotationAngle? angle,
    RotateStatus? status,
    double? progress,
    String? progressMessage,
    String? outputFilePath,
    int? outputSizeBytes,
    int? pageCount,
    String? errorMessage,
    bool clearInput = false,
  }) {
    return RotatePdfState(
      inputFile: clearInput ? null : (inputFile ?? this.inputFile),
      inputFileName: clearInput ? null : (inputFileName ?? this.inputFileName),
      inputSizeBytes: clearInput ? 0 : (inputSizeBytes ?? this.inputSizeBytes),
      angle: angle ?? this.angle,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      outputFilePath: outputFilePath ?? this.outputFilePath,
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      errorMessage: errorMessage,
    );
  }
}

// ─── PROVIDER ───────────────────────────────────────────────────────────────

final rotatePdfProvider = StateNotifierProvider.autoDispose<RotatePdfNotifier, RotatePdfState>((ref) {
  return RotatePdfNotifier(ref);
});

class RotatePdfNotifier extends StateNotifier<RotatePdfState> {
  final Ref _ref;
  final RotatePdfService _service = RotatePdfService();
  final LabFileManager _fileManager = LabFileManager();
  bool _isCancelled = false;

  RotatePdfNotifier(this._ref) : super(const RotatePdfState());

  Future<void> pickFile() async {
    if (state.isProcessing) return;
    state = state.copyWith(status: RotateStatus.picking);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        state = state.copyWith(status: state.inputFile != null ? RotateStatus.ready : RotateStatus.idle);
        return;
      }

      final file = File(result.files.first.path!);
      final size = await file.length();
      final name = result.files.first.name;

      state = state.copyWith(
        inputFile: file,
        inputFileName: name,
        inputSizeBytes: size,
        status: RotateStatus.ready,
      );
    } catch (e) {
      state = state.copyWith(
        status: RotateStatus.error,
        errorMessage: 'Could not pick file.',
      );
    }
  }

  void setAngle(RotationAngle angle) {
    if (state.isProcessing) return;
    state = state.copyWith(angle: angle);
  }

  Future<void> startRotation() async {
    if (!state.canProcess) return;

    _isCancelled = false;
    state = state.copyWith(
      status: RotateStatus.processing,
      progress: 0.0,
      errorMessage: null,
    );

    try {
      final result = await _service.rotatePdf(
        inputFile: state.inputFile!,
        outputFileName: state.inputFileName ?? 'rotated',
        angle: state.angle,
        isCancelled: () => _isCancelled,
        onProgress: (p, msg) {
          if (mounted) {
            state = state.copyWith(progress: p, progressMessage: msg);
          }
        },
      );

      if (!mounted) return;

      _ref.read(labRecentFilesProvider.notifier).addFile(
        LabRecentFile(
          filePath: result.outputPath,
          fileName: result.outputPath.split(Platform.pathSeparator).last,
          sizeBytes: result.outputSizeBytes,
          toolId: 'rotate_pdf',
          toolLabel: 'Rotate PDF',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        status: RotateStatus.success,
        outputFilePath: result.outputPath,
        outputSizeBytes: result.outputSizeBytes,
        pageCount: result.pageCount,
        progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: RotateStatus.error,
        errorMessage: e is RotatePdfError ? e.userMessage : 'Rotation failed.',
      );
    }
  }

  void cancelRotation() {
    _isCancelled = true;
  }

  Future<void> reset() async {
    await _fileManager.cleanupToolTemp('RotatePDF');
    state = const RotatePdfState();
  }

  void dismissError() {
    state = state.copyWith(
      status: state.inputFile != null ? RotateStatus.ready : RotateStatus.idle,
      errorMessage: null,
    );
  }

  @override
  void dispose() {
    _fileManager.cleanupToolTemp('RotatePDF');
    super.dispose();
  }
}
