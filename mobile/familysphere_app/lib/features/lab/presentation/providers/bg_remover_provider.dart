import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/bg_remover_service.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

enum BgRemoverStatus { idle, picking, ready, processing, success, error }

class BgRemoverState {
  final File? inputFile;
  final String? inputFileName;
  final int inputSizeBytes;
  final int tolerance;
  final BgRemoverStatus status;
  final double progress;
  final String progressMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;
  final int? pixelsRemoved;
  final String? errorMessage;

  const BgRemoverState({
    this.inputFile, this.inputFileName, this.inputSizeBytes = 0,
    this.tolerance = 30, this.status = BgRemoverStatus.idle,
    this.progress = 0.0, this.progressMessage = '', this.outputFilePath,
    this.outputSizeBytes, this.pixelsRemoved, this.errorMessage,
  });

  bool get isProcessing => status == BgRemoverStatus.picking || status == BgRemoverStatus.processing;
  bool get canProcess => status == BgRemoverStatus.ready && inputFile != null;

  BgRemoverState copyWith({
    File? inputFile, String? inputFileName, int? inputSizeBytes,
    int? tolerance, BgRemoverStatus? status, double? progress,
    String? progressMessage, String? outputFilePath, int? outputSizeBytes,
    int? pixelsRemoved, String? errorMessage, bool clearAll = false,
  }) {
    return BgRemoverState(
      inputFile: clearAll ? null : (inputFile ?? this.inputFile),
      inputFileName: clearAll ? null : (inputFileName ?? this.inputFileName),
      inputSizeBytes: clearAll ? 0 : (inputSizeBytes ?? this.inputSizeBytes),
      tolerance: tolerance ?? this.tolerance,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      outputFilePath: clearAll ? null : (outputFilePath ?? this.outputFilePath),
      outputSizeBytes: clearAll ? null : (outputSizeBytes ?? this.outputSizeBytes),
      pixelsRemoved: clearAll ? null : (pixelsRemoved ?? this.pixelsRemoved),
      errorMessage: errorMessage,
    );
  }
}

final bgRemoverProvider = StateNotifierProvider.autoDispose<BgRemoverNotifier, BgRemoverState>((ref) {
  return BgRemoverNotifier(ref);
});

class BgRemoverNotifier extends StateNotifier<BgRemoverState> {
  final Ref _ref;
  final BgRemoverService _service = BgRemoverService();

  BgRemoverNotifier(this._ref) : super(const BgRemoverState());

  Future<void> pickFile() async {
    if (state.isProcessing) return;
    state = state.copyWith(status: BgRemoverStatus.picking);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        state = state.copyWith(status: state.inputFile != null ? BgRemoverStatus.ready : BgRemoverStatus.idle);
        return;
      }
      final file = File(result.files.first.path!);
      state = state.copyWith(
        inputFile: file, inputFileName: result.files.first.name,
        inputSizeBytes: await file.length(), status: BgRemoverStatus.ready,
      );
    } catch (e) {
      state = state.copyWith(status: BgRemoverStatus.error, errorMessage: 'Could not pick file.');
    }
  }

  void setTolerance(int t) {
    if (!state.isProcessing) state = state.copyWith(tolerance: t.clamp(5, 100));
  }

  Future<void> startRemoval() async {
    if (!state.canProcess) return;
    state = state.copyWith(status: BgRemoverStatus.processing, progress: 0.0, errorMessage: null);
    try {
      final result = await _service.removeBackground(
        inputFile: state.inputFile!, outputFileName: state.inputFileName ?? 'no_bg',
        tolerance: state.tolerance,
        onProgress: (p, msg) { if (mounted) state = state.copyWith(progress: p, progressMessage: msg); },
      );
      if (!mounted) return;
      _ref.read(labRecentFilesProvider.notifier).addFile(LabRecentFile(
        filePath: result.outputPath, fileName: result.outputPath.split(Platform.pathSeparator).last,
        sizeBytes: result.outputSizeBytes, toolId: 'bg_remover', toolLabel: 'BG Remover',
        createdAt: DateTime.now(),
      ));
      state = state.copyWith(
        status: BgRemoverStatus.success, outputFilePath: result.outputPath,
        outputSizeBytes: result.outputSizeBytes, pixelsRemoved: result.pixelsRemoved, progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(status: BgRemoverStatus.error,
          errorMessage: e is BgRemoverError ? e.userMessage : 'Background removal failed.');
    }
  }

  Future<void> reset() async { state = const BgRemoverState(); }
  void dismissError() { state = state.copyWith(status: state.inputFile != null ? BgRemoverStatus.ready : BgRemoverStatus.idle, errorMessage: null); }
}
