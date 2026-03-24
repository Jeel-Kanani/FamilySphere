import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/image_convert_service.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

enum ImgConvertStatus { idle, picking, ready, converting, success, error }

class ImgConvertState {
  final File? inputFile;
  final String? inputFileName;
  final int inputSizeBytes;
  final String? sourceFormat;
  final ConvertFormat targetFormat;
  final ImgConvertStatus status;
  final double progress;
  final String progressMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;
  final String? errorMessage;

  const ImgConvertState({
    this.inputFile, this.inputFileName, this.inputSizeBytes = 0,
    this.sourceFormat, this.targetFormat = ConvertFormat.png,
    this.status = ImgConvertStatus.idle, this.progress = 0.0,
    this.progressMessage = '', this.outputFilePath, this.outputSizeBytes,
    this.errorMessage,
  });

  bool get isProcessing => status == ImgConvertStatus.picking || status == ImgConvertStatus.converting;
  bool get canConvert => status == ImgConvertStatus.ready && inputFile != null;

  ImgConvertState copyWith({
    File? inputFile, String? inputFileName, int? inputSizeBytes,
    String? sourceFormat, ConvertFormat? targetFormat,
    ImgConvertStatus? status, double? progress, String? progressMessage,
    String? outputFilePath, int? outputSizeBytes, String? errorMessage,
    bool clearAll = false,
  }) {
    return ImgConvertState(
      inputFile: clearAll ? null : (inputFile ?? this.inputFile),
      inputFileName: clearAll ? null : (inputFileName ?? this.inputFileName),
      inputSizeBytes: clearAll ? 0 : (inputSizeBytes ?? this.inputSizeBytes),
      sourceFormat: clearAll ? null : (sourceFormat ?? this.sourceFormat),
      targetFormat: targetFormat ?? this.targetFormat,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      outputFilePath: clearAll ? null : (outputFilePath ?? this.outputFilePath),
      outputSizeBytes: clearAll ? null : (outputSizeBytes ?? this.outputSizeBytes),
      errorMessage: errorMessage,
    );
  }
}

final imageConvertProvider = StateNotifierProvider.autoDispose<ImgConvertNotifier, ImgConvertState>((ref) {
  return ImgConvertNotifier(ref);
});

class ImgConvertNotifier extends StateNotifier<ImgConvertState> {
  final Ref _ref;
  final ImageConvertService _service = ImageConvertService();

  ImgConvertNotifier(this._ref) : super(const ImgConvertState());

  Future<void> pickFile() async {
    if (state.isProcessing) return;
    state = state.copyWith(status: ImgConvertStatus.picking);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        state = state.copyWith(status: state.inputFile != null ? ImgConvertStatus.ready : ImgConvertStatus.idle);
        return;
      }
      final file = File(result.files.first.path!);
      final ext = result.files.first.name.split('.').last.toUpperCase();
      state = state.copyWith(
        inputFile: file, inputFileName: result.files.first.name,
        inputSizeBytes: await file.length(), sourceFormat: ext, status: ImgConvertStatus.ready,
      );
    } catch (e) {
      state = state.copyWith(status: ImgConvertStatus.error, errorMessage: 'Could not pick file.');
    }
  }

  void setTargetFormat(ConvertFormat fmt) {
    if (!state.isProcessing) state = state.copyWith(targetFormat: fmt);
  }

  Future<void> startConvert() async {
    if (!state.canConvert) return;
    state = state.copyWith(status: ImgConvertStatus.converting, progress: 0.0, errorMessage: null);
    try {
      final result = await _service.convertImage(
        inputFile: state.inputFile!, outputFileName: state.inputFileName ?? 'converted',
        targetFormat: state.targetFormat,
        onProgress: (p, msg) { if (mounted) state = state.copyWith(progress: p, progressMessage: msg); },
      );
      if (!mounted) return;
      _ref.read(labRecentFilesProvider.notifier).addFile(LabRecentFile(
        filePath: result.outputPath, fileName: result.outputPath.split(Platform.pathSeparator).last,
        sizeBytes: result.outputSizeBytes, toolId: 'image_convert', toolLabel: 'Convert Image',
        createdAt: DateTime.now(),
      ));
      state = state.copyWith(
        status: ImgConvertStatus.success, outputFilePath: result.outputPath,
        outputSizeBytes: result.outputSizeBytes, progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(status: ImgConvertStatus.error,
          errorMessage: e is ImageConvertError ? e.userMessage : 'Conversion failed.');
    }
  }

  Future<void> reset() async { state = const ImgConvertState(); }
  void dismissError() { state = state.copyWith(status: state.inputFile != null ? ImgConvertStatus.ready : ImgConvertStatus.idle, errorMessage: null); }
}
