import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:familysphere_app/features/lab/domain/services/split_pdf_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── STATE ───────────────────────────────────────────────────────────────────

enum SplitStatus {
  idle,
  picking,
  validating,
  splitting,
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

class SplitPdfState {
  final SelectedPdfFile? selectedFile;
  final SplitMode mode;
  final String rangeString;
  final String outputFileName;
  final SplitStatus status;
  final double progress;
  final String progressMessage;
  final String? errorMessage;
  final List<String> outputFilePaths;

  const SplitPdfState({
    this.selectedFile,
    this.mode = SplitMode.range,
    this.rangeString = '',
    this.outputFileName = 'split_pages.pdf',
    this.status = SplitStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.errorMessage,
    this.outputFilePaths = const [],
  });

  bool get canSplit =>
      selectedFile != null &&
      (mode == SplitMode.individual || rangeString.trim().isNotEmpty) &&
      status == SplitStatus.idle;

  bool get isProcessing =>
      status == SplitStatus.validating ||
      status == SplitStatus.splitting ||
      status == SplitStatus.picking;

  SplitPdfState copyWith({
    SelectedPdfFile? selectedFile,
    SplitMode? mode,
    String? rangeString,
    String? outputFileName,
    SplitStatus? status,
    double? progress,
    String? progressMessage,
    String? errorMessage,
    List<String>? outputFilePaths,
    bool clearSelectedFile = false,
  }) {
    return SplitPdfState(
      selectedFile: clearSelectedFile ? null : (selectedFile ?? this.selectedFile),
      mode: mode ?? this.mode,
      rangeString: rangeString ?? this.rangeString,
      outputFileName: outputFileName ?? this.outputFileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      errorMessage: errorMessage,
      outputFilePaths: outputFilePaths ?? this.outputFilePaths,
    );
  }
}

// ─── PROVIDER ────────────────────────────────────────────────────────────────

final splitPdfProvider =
    StateNotifierProvider.autoDispose<SplitPdfNotifier, SplitPdfState>((ref) {
  return SplitPdfNotifier(ref);
});

class SplitPdfNotifier extends StateNotifier<SplitPdfState> {
  SplitPdfNotifier(this._ref) : super(const SplitPdfState());

  final Ref _ref;
  final SplitPdfService _splitService = SplitPdfService();
  final LabFileManager _fileManager = LabFileManager();
  bool _isCancelled = false;

  /// Opens file picker to select a single PDF.
  Future<void> pickFile() async {
    if (state.isProcessing) return;

    state = state.copyWith(status: SplitStatus.picking);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        state = state.copyWith(status: SplitStatus.idle);
        return;
      }

      final platformFile = result.files.first;
      final file = File(platformFile.path!);
      
      // Extract page count
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      document.dispose();

      state = state.copyWith(
        selectedFile: SelectedPdfFile(
          name: platformFile.name,
          path: platformFile.path!,
          sizeBytes: platformFile.size,
          pageCount: pageCount,
        ),
        status: SplitStatus.idle,
        outputFileName: 'split_${platformFile.name}',
      );
    } catch (e) {
      state = state.copyWith(
        status: SplitStatus.error,
        errorMessage: 'Could not open file picker.',
      );
    }
  }

  void removeFile() {
    if (state.isProcessing) return;
    state = state.copyWith(clearSelectedFile: true, status: SplitStatus.idle);
  }

  void setMode(SplitMode mode) {
    if (state.isProcessing) return;
    state = state.copyWith(mode: mode);
  }

  void setRange(String range) {
    if (state.isProcessing) return;
    state = state.copyWith(rangeString: range);
  }

  void setOutputName(String name) {
    if (state.isProcessing) return;
    state = state.copyWith(outputFileName: name);
  }

  Future<void> startSplit() async {
    if (!state.canSplit) return;

    _isCancelled = false;
    state = state.copyWith(
      status: SplitStatus.validating,
      progress: 0.0,
      progressMessage: 'Starting...',
    );

    try {
      final inputFile = File(state.selectedFile!.path);
      
      final result = await _splitService.splitPdf(
        inputFile: inputFile,
        outputFileName: state.outputFileName,
        mode: state.mode,
        rangeString: state.rangeString,
        isCancelled: () => _isCancelled,
        onProgress: (progress, statusMsg) {
          if (!mounted) return;
          state = state.copyWith(
            status: SplitStatus.splitting,
            progress: progress,
            progressMessage: statusMsg,
          );
        },
      );

      if (!mounted) return;

      // Add to recent files
      for (final path in result.outputPaths) {
        final fileName = path.split(Platform.pathSeparator).last;
        final file = File(path);
        final size = await file.length();

        _ref.read(labRecentFilesProvider.notifier).addFile(
          LabRecentFile(
            filePath: path,
            fileName: fileName,
            sizeBytes: size,
            toolId: 'split_pdf',
            toolLabel: 'Split PDF',
            createdAt: DateTime.now(),
          ),
        );
      }

      state = state.copyWith(
        status: SplitStatus.success,
        progress: 1.0,
        progressMessage: 'Done!',
        outputFilePaths: result.outputPaths,
      );
    } on SplitCancelledError {
      await _fileManager.cleanupToolTemp('SplitPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: SplitStatus.idle,
        errorMessage: 'Operation cancelled.',
      );
    } on SplitPdfError catch (e) {
      await _fileManager.cleanupToolTemp('SplitPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: SplitStatus.error,
        errorMessage: e.userMessage,
      );
    } catch (e) {
      await _fileManager.cleanupToolTemp('SplitPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: SplitStatus.error,
        errorMessage: 'An unexpected error occurred.',
      );
    }
  }

  void cancelSplit() {
    _isCancelled = true;
  }

  void reset() {
    state = const SplitPdfState();
  }

  void dismissError() {
    state = state.copyWith(status: SplitStatus.idle);
  }
}
