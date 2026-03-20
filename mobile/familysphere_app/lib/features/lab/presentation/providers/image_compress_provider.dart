import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/image_compress_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

enum ImgCompressStatus { idle, picking, ready, compressing, success, error }

class ImgCompressState {
  final File? inputFile;
  final String? inputFileName;
  final int inputSizeBytes;
  final ImageQuality quality;
  final ImgCompressStatus status;
  final double progress;
  final String progressMessage;
  final String? outputFilePath;
  final int? compressedSize;
  final double? savingsPercent;
  final String? errorMessage;

  const ImgCompressState({
    this.inputFile, this.inputFileName, this.inputSizeBytes = 0,
    this.quality = ImageQuality.medium, this.status = ImgCompressStatus.idle,
    this.progress = 0.0, this.progressMessage = '', this.outputFilePath,
    this.compressedSize, this.savingsPercent, this.errorMessage,
  });

  bool get isProcessing => status == ImgCompressStatus.picking || status == ImgCompressStatus.compressing;
  bool get canCompress => status == ImgCompressStatus.ready && inputFile != null;

  ImgCompressState copyWith({
    File? inputFile, String? inputFileName, int? inputSizeBytes,
    ImageQuality? quality, ImgCompressStatus? status, double? progress,
    String? progressMessage, String? outputFilePath, int? compressedSize,
    double? savingsPercent, String? errorMessage, bool clearInput = false,
  }) {
    return ImgCompressState(
      inputFile: clearInput ? null : (inputFile ?? this.inputFile),
      inputFileName: clearInput ? null : (inputFileName ?? this.inputFileName),
      inputSizeBytes: clearInput ? 0 : (inputSizeBytes ?? this.inputSizeBytes),
      quality: quality ?? this.quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      outputFilePath: clearInput ? null : (outputFilePath ?? this.outputFilePath),
      compressedSize: clearInput ? null : (compressedSize ?? this.compressedSize),
      savingsPercent: clearInput ? null : (savingsPercent ?? this.savingsPercent),
      errorMessage: errorMessage,
    );
  }
}

final imageCompressProvider = StateNotifierProvider.autoDispose<ImgCompressNotifier, ImgCompressState>((ref) {
  return ImgCompressNotifier(ref);
});

class ImgCompressNotifier extends StateNotifier<ImgCompressState> {
  final Ref _ref;
  final ImageCompressService _service = ImageCompressService();
  bool _isCancelled = false;

  ImgCompressNotifier(this._ref) : super(const ImgCompressState());

  Future<void> pickFile() async {
    if (state.isProcessing) return;
    state = state.copyWith(status: ImgCompressStatus.picking);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        state = state.copyWith(status: state.inputFile != null ? ImgCompressStatus.ready : ImgCompressStatus.idle);
        return;
      }
      final file = File(result.files.first.path!);
      state = state.copyWith(
        inputFile: file, inputFileName: result.files.first.name,
        inputSizeBytes: await file.length(), status: ImgCompressStatus.ready,
      );
    } catch (e) {
      state = state.copyWith(status: ImgCompressStatus.error, errorMessage: 'Could not pick file.');
    }
  }

  void setQuality(ImageQuality q) {
    if (!state.isProcessing) state = state.copyWith(quality: q);
  }

  Future<void> startCompress() async {
    if (!state.canCompress) return;
    _isCancelled = false;
    state = state.copyWith(status: ImgCompressStatus.compressing, progress: 0.0, errorMessage: null);
    try {
      final result = await _service.compressImage(
        inputFile: state.inputFile!, outputFileName: state.inputFileName ?? 'compressed',
        quality: state.quality, isCancelled: () => _isCancelled,
        onProgress: (p, msg) { if (mounted) state = state.copyWith(progress: p, progressMessage: msg); },
      );
      if (!mounted) return;
      _ref.read(labRecentFilesProvider.notifier).addFile(LabRecentFile(
        filePath: result.outputPath, fileName: result.outputPath.split(Platform.pathSeparator).last,
        sizeBytes: result.compressedSize, toolId: 'image_compress', toolLabel: 'Compress Image',
        createdAt: DateTime.now(),
      ));
      state = state.copyWith(
        status: ImgCompressStatus.success, outputFilePath: result.outputPath,
        compressedSize: result.compressedSize, savingsPercent: result.savingsPercent, progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(status: ImgCompressStatus.error,
          errorMessage: e is ImageCompressError ? e.userMessage : 'Compression failed.');
    }
  }

  Future<void> reset() async { state = const ImgCompressState(); }
  void dismissError() { state = state.copyWith(status: state.inputFile != null ? ImgCompressStatus.ready : ImgCompressStatus.idle, errorMessage: null); }
}
