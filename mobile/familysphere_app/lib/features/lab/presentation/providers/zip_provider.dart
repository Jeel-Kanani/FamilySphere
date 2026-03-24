import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/zip_service.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

enum ZipMode { zip, unzip }
enum ZipStatus { idle, picking, ready, processing, success, error }

class ZipState {
  final ZipMode mode;
  final List<File> inputFiles;
  final List<String> inputFileNames;
  final File? archiveFile;
  final String? archiveFileName;
  final ZipStatus status;
  final double progress;
  final String progressMessage;
  final String? outputPath;
  final int? outputSizeBytes;
  final int? fileCount;
  final List<String>? extractedFiles;
  final String? errorMessage;

  const ZipState({
    this.mode = ZipMode.zip,
    this.inputFiles = const [],
    this.inputFileNames = const [],
    this.archiveFile,
    this.archiveFileName,
    this.status = ZipStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.outputPath,
    this.outputSizeBytes,
    this.fileCount,
    this.extractedFiles,
    this.errorMessage,
  });

  bool get isProcessing => status == ZipStatus.picking || status == ZipStatus.processing;
  bool get canProcess {
    if (mode == ZipMode.zip) return status == ZipStatus.ready && inputFiles.isNotEmpty;
    return status == ZipStatus.ready && archiveFile != null;
  }

  ZipState copyWith({
    ZipMode? mode, List<File>? inputFiles, List<String>? inputFileNames,
    File? archiveFile, String? archiveFileName, ZipStatus? status,
    double? progress, String? progressMessage, String? outputPath,
    int? outputSizeBytes, int? fileCount, List<String>? extractedFiles,
    String? errorMessage, bool clearAll = false,
  }) {
    return ZipState(
      mode: mode ?? this.mode,
      inputFiles: clearAll ? [] : (inputFiles ?? this.inputFiles),
      inputFileNames: clearAll ? [] : (inputFileNames ?? this.inputFileNames),
      archiveFile: clearAll ? null : (archiveFile ?? this.archiveFile),
      archiveFileName: clearAll ? null : (archiveFileName ?? this.archiveFileName),
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      outputPath: clearAll ? null : (outputPath ?? this.outputPath),
      outputSizeBytes: clearAll ? null : (outputSizeBytes ?? this.outputSizeBytes),
      fileCount: clearAll ? null : (fileCount ?? this.fileCount),
      extractedFiles: clearAll ? null : (extractedFiles ?? this.extractedFiles),
      errorMessage: errorMessage,
    );
  }
}

final zipProvider = StateNotifierProvider.autoDispose<ZipNotifier, ZipState>((ref) {
  return ZipNotifier(ref);
});

class ZipNotifier extends StateNotifier<ZipState> {
  final Ref _ref;
  final ZipService _service = ZipService();

  ZipNotifier(this._ref) : super(const ZipState());

  void setMode(ZipMode mode) {
    if (!state.isProcessing) state = ZipState(mode: mode);
  }

  Future<void> pickFiles() async {
    if (state.isProcessing) return;
    state = state.copyWith(status: ZipStatus.picking);

    try {
      if (state.mode == ZipMode.zip) {
        final result = await FilePicker.platform.pickFiles(allowMultiple: true);
        if (result == null || result.files.isEmpty) {
          state = state.copyWith(status: state.inputFiles.isNotEmpty ? ZipStatus.ready : ZipStatus.idle);
          return;
        }
        final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
        final names = result.files.where((f) => f.path != null).map((f) => f.name).toList();
        state = state.copyWith(inputFiles: files, inputFileNames: names, status: ZipStatus.ready);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['zip', 'gz'],
        );
        if (result == null || result.files.isEmpty || result.files.first.path == null) {
          state = state.copyWith(status: state.archiveFile != null ? ZipStatus.ready : ZipStatus.idle);
          return;
        }
        state = state.copyWith(
          archiveFile: File(result.files.first.path!),
          archiveFileName: result.files.first.name,
          status: ZipStatus.ready,
        );
      }
    } catch (e) {
      state = state.copyWith(status: ZipStatus.error, errorMessage: 'Could not pick files.');
    }
  }

  Future<void> startProcess() async {
    if (!state.canProcess) return;
    state = state.copyWith(status: ZipStatus.processing, progress: 0.0, errorMessage: null);

    try {
      if (state.mode == ZipMode.zip) {
        final result = await _service.zipFiles(
          inputFiles: state.inputFiles, outputFileName: 'archive',
          onProgress: (p, msg) { if (mounted) state = state.copyWith(progress: p, progressMessage: msg); },
        );
        if (!mounted) return;
        _ref.read(labRecentFilesProvider.notifier).addFile(LabRecentFile(
          filePath: result.outputPath, fileName: result.outputPath.split(Platform.pathSeparator).last,
          sizeBytes: result.outputSizeBytes, toolId: 'zip', toolLabel: 'Zip Files',
          createdAt: DateTime.now(),
        ));
        state = state.copyWith(status: ZipStatus.success, outputPath: result.outputPath,
          outputSizeBytes: result.outputSizeBytes, fileCount: result.fileCount, progress: 1.0);
      } else {
        final result = await _service.unzipFile(
          inputFile: state.archiveFile!,
          onProgress: (p, msg) { if (mounted) state = state.copyWith(progress: p, progressMessage: msg); },
        );
        if (!mounted) return;
        state = state.copyWith(status: ZipStatus.success, outputPath: result.outputDirPath,
          outputSizeBytes: result.totalSizeBytes, fileCount: result.extractedFiles.length,
          extractedFiles: result.extractedFiles, progress: 1.0);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(status: ZipStatus.error,
          errorMessage: e is ZipError ? e.userMessage : 'Operation failed.');
    }
  }

  Future<void> reset() async { state = ZipState(mode: state.mode); }
  void dismissError() { state = state.copyWith(status: ZipStatus.idle, errorMessage: null); }
}
