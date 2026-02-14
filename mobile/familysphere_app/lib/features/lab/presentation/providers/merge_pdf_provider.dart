import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/pdf_merge_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── STATE ───────────────────────────────────────────────────────────────────

enum MergeStatus {
  idle,
  picking,
  validating,
  merging,
  success,
  error,
}

class SelectedPdfFile {
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime lastModified;

  const SelectedPdfFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.lastModified,
  });

  String get sizeLabel => LabFileManager.formatFileSize(sizeBytes);

  String get dateLabel {
    final now = DateTime.now();
    final diff = now.difference(lastModified);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${lastModified.day}/${lastModified.month}/${lastModified.year}';
  }
}

class MergePdfState {
  final List<SelectedPdfFile> selectedFiles;
  final String outputFileName;
  final MergeStatus status;
  final double progress;
  final String progressMessage;
  final String? errorMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;

  const MergePdfState({
    this.selectedFiles = const [],
    this.outputFileName = 'merged_file.pdf',
    this.status = MergeStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.errorMessage,
    this.outputFilePath,
    this.outputSizeBytes,
  });

  bool get canMerge =>
      selectedFiles.length >= PdfMergeService.minFiles &&
      status == MergeStatus.idle;

  bool get isProcessing =>
      status == MergeStatus.validating ||
      status == MergeStatus.merging ||
      status == MergeStatus.picking;

  int get totalSizeBytes {
    int total = 0;
    for (final f in selectedFiles) {
      total += f.sizeBytes;
    }
    return total;
  }

  String get totalSizeLabel => LabFileManager.formatFileSize(totalSizeBytes);

  MergePdfState copyWith({
    List<SelectedPdfFile>? selectedFiles,
    String? outputFileName,
    MergeStatus? status,
    double? progress,
    String? progressMessage,
    String? errorMessage,
    String? outputFilePath,
    int? outputSizeBytes,
  }) {
    return MergePdfState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      outputFileName: outputFileName ?? this.outputFileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      errorMessage: errorMessage,
      outputFilePath: outputFilePath,
      outputSizeBytes: outputSizeBytes,
    );
  }
}

// ─── PROVIDER ────────────────────────────────────────────────────────────────

final mergePdfProvider =
    StateNotifierProvider.autoDispose<MergePdfNotifier, MergePdfState>((ref) {
  return MergePdfNotifier(ref);
});

class MergePdfNotifier extends StateNotifier<MergePdfState> {
  MergePdfNotifier(this._ref) : super(const MergePdfState());

  final Ref _ref;
  final PdfMergeService _mergeService = PdfMergeService();
  final LabFileManager _fileManager = LabFileManager();
  bool _isCancelled = false;

  // ─── FILE SELECTION ──────────────────────────────────────────────────────

  /// Opens file picker to select PDF files.
  Future<void> pickFiles() async {
    if (state.isProcessing) return;

    state = state.copyWith(status: MergeStatus.picking);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: MergeStatus.idle);
        return;
      }

      final newFiles = <SelectedPdfFile>[];
      for (final platformFile in result.files) {
        if (platformFile.path == null) continue;

        // Skip duplicates
        final alreadySelected = state.selectedFiles.any(
          (f) => f.path == platformFile.path,
        );
        if (alreadySelected) continue;

        final file = File(platformFile.path!);
        final stat = await file.stat();

        newFiles.add(SelectedPdfFile(
          name: platformFile.name,
          path: platformFile.path!,
          sizeBytes: platformFile.size,
          lastModified: stat.modified,
        ));
      }

      // Enforce max file limit
      final combined = [...state.selectedFiles, ...newFiles];
      final capped = combined.length > PdfMergeService.maxFiles
          ? combined.sublist(0, PdfMergeService.maxFiles)
          : combined;

      // Check total size
      int totalSize = 0;
      for (final f in capped) {
        totalSize += f.sizeBytes;
      }

      if (totalSize > PdfMergeService.maxTotalSizeBytes) {
        state = state.copyWith(
          status: MergeStatus.error,
          errorMessage:
              'Total file size (${LabFileManager.formatFileSize(totalSize)}) '
              'exceeds the ${LabFileManager.formatFileSize(PdfMergeService.maxTotalSizeBytes)} limit.',
        );
        return;
      }

      state = state.copyWith(
        selectedFiles: capped,
        status: MergeStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(
        status: MergeStatus.idle,
        errorMessage: 'Could not open file picker.',
      );
    }
  }

  /// Removes a file at the given index.
  void removeFile(int index) {
    if (state.isProcessing) return;
    if (index < 0 || index >= state.selectedFiles.length) return;

    final updated = List<SelectedPdfFile>.from(state.selectedFiles)
      ..removeAt(index);
    state = state.copyWith(
      selectedFiles: updated,
      status: MergeStatus.idle,
    );
  }

  /// Reorders files from [oldIndex] to [newIndex].
  void reorderFiles(int oldIndex, int newIndex) {
    if (state.isProcessing) return;
    if (newIndex > oldIndex) newIndex--;

    final updated = List<SelectedPdfFile>.from(state.selectedFiles);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    state = state.copyWith(selectedFiles: updated);
  }

  /// Sets the output file name.
  void setOutputName(String name) {
    if (state.isProcessing) return;
    state = state.copyWith(outputFileName: name);
  }

  // ─── MERGE ───────────────────────────────────────────────────────────────

  /// Starts the merge process.
  Future<void> startMerge() async {
    if (!state.canMerge) return;

    _isCancelled = false;

    state = state.copyWith(
      status: MergeStatus.validating,
      progress: 0.0,
      progressMessage: 'Validating files...',
    );

    try {
      final inputFiles =
          state.selectedFiles.map((f) => File(f.path)).toList();

      final result = await _mergeService.mergePdfs(
        inputFiles: inputFiles,
        outputFileName: state.outputFileName,
        isCancelled: () => _isCancelled,
        onProgress: (progress, statusMsg) {
          if (!mounted) return;
          state = state.copyWith(
            status: MergeStatus.merging,
            progress: progress,
            progressMessage: statusMsg,
          );
        },
      );

      if (!mounted) return;

      // Add to Lab recent files so it shows on the Lab screen
      final fileName = result.outputPath.split(Platform.pathSeparator).last;
      _ref.read(labRecentFilesProvider.notifier).addFile(
        LabRecentFile(
          filePath: result.outputPath,
          fileName: fileName,
          sizeBytes: result.outputSizeBytes,
          toolId: 'merge_pdf',
          toolLabel: 'Merge PDF',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        status: MergeStatus.success,
        progress: 1.0,
        progressMessage: 'Done!',
        outputFilePath: result.outputPath,
        outputSizeBytes: result.outputSizeBytes,
      );
    } on CancelledError {
      await _fileManager.cleanupToolTemp('MergePDF');
      if (!mounted) return;
      state = state.copyWith(
        status: MergeStatus.idle,
        progress: 0.0,
        progressMessage: '',
        errorMessage: 'Merge cancelled. No files were changed.',
      );
    } on MergeError catch (e) {
      await _fileManager.cleanupToolTemp('MergePDF');
      if (!mounted) return;
      // Keep selectedFiles intact so user can retry
      state = state.copyWith(
        status: MergeStatus.error,
        progress: 0.0,
        progressMessage: '',
        errorMessage: e.userMessage,
      );
    } catch (e) {
      await _fileManager.cleanupToolTemp('MergePDF');
      if (!mounted) return;
      state = state.copyWith(
        status: MergeStatus.error,
        progress: 0.0,
        progressMessage: '',
        errorMessage:
            'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Cancels an in-progress merge.
  void cancelMerge() {
    _isCancelled = true;
  }

  /// Resets state back to idle (after viewing result).
  void reset() {
    state = const MergePdfState();
  }

  /// Dismisses the error and returns to idle (keeping files selected).
  void dismissError() {
    state = state.copyWith(
      status: MergeStatus.idle,
      progress: 0.0,
      progressMessage: '',
    );
  }
}
