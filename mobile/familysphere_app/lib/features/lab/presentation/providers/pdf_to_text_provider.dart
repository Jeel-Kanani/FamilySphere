import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/pdf_to_text_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── STATE ──────────────────────────────────────────────────────────────────

enum PdfToTextStatus { idle, picking, processing, success, error }

class PdfToTextState {
  final File? inputFile;
  final String? inputFileName;
  final int inputSizeBytes;
  final PdfToTextStatus status;
  final double progress;
  final String progressMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;
  final int? pageCount;
  final int? characterCount;
  final String? extractedText;
  final String? errorMessage;

  const PdfToTextState({
    this.inputFile,
    this.inputFileName,
    this.inputSizeBytes = 0,
    this.status = PdfToTextStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.outputFilePath,
    this.outputSizeBytes,
    this.pageCount,
    this.characterCount,
    this.extractedText,
    this.errorMessage,
  });

  bool get isProcessing => status == PdfToTextStatus.picking || status == PdfToTextStatus.processing;

  PdfToTextState copyWith({
    File? inputFile,
    String? inputFileName,
    int? inputSizeBytes,
    PdfToTextStatus? status,
    double? progress,
    String? progressMessage,
    String? outputFilePath,
    int? outputSizeBytes,
    int? pageCount,
    int? characterCount,
    String? extractedText,
    String? errorMessage,
    bool clearAll = false,
  }) {
    return PdfToTextState(
      inputFile: clearAll ? null : (inputFile ?? this.inputFile),
      inputFileName: clearAll ? null : (inputFileName ?? this.inputFileName),
      inputSizeBytes: clearAll ? 0 : (inputSizeBytes ?? this.inputSizeBytes),
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      outputFilePath: clearAll ? null : (outputFilePath ?? this.outputFilePath),
      outputSizeBytes: clearAll ? null : (outputSizeBytes ?? this.outputSizeBytes),
      pageCount: clearAll ? null : (pageCount ?? this.pageCount),
      characterCount: clearAll ? null : (characterCount ?? this.characterCount),
      extractedText: clearAll ? null : (extractedText ?? this.extractedText),
      errorMessage: errorMessage,
    );
  }
}

// ─── PROVIDER ───────────────────────────────────────────────────────────────

final pdfToTextProvider = StateNotifierProvider.autoDispose<PdfToTextNotifier, PdfToTextState>((ref) {
  return PdfToTextNotifier(ref);
});

class PdfToTextNotifier extends StateNotifier<PdfToTextState> {
  final Ref _ref;
  final PdfToTextService _service = PdfToTextService();
  final LabFileManager _fileManager = LabFileManager();
  bool _isCancelled = false;

  PdfToTextNotifier(this._ref) : super(const PdfToTextState());

  Future<void> pickAndExtract() async {
    if (state.isProcessing) return;
    state = state.copyWith(status: PdfToTextStatus.picking);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        state = state.copyWith(status: PdfToTextStatus.idle);
        return;
      }

      final file = File(result.files.first.path!);
      final size = await file.length();
      final name = result.files.first.name;

      state = state.copyWith(
        inputFile: file,
        inputFileName: name,
        inputSizeBytes: size,
        status: PdfToTextStatus.processing,
        progress: 0.0,
      );

      _isCancelled = false;

      final textResult = await _service.extractText(
        inputFile: file,
        outputFileName: name.replaceAll('.pdf', ''),
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
          filePath: textResult.outputPath,
          fileName: textResult.outputPath.split(Platform.pathSeparator).last,
          sizeBytes: textResult.outputSizeBytes,
          toolId: 'pdf_to_text',
          toolLabel: 'PDF to Text',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        status: PdfToTextStatus.success,
        outputFilePath: textResult.outputPath,
        outputSizeBytes: textResult.outputSizeBytes,
        pageCount: textResult.pageCount,
        characterCount: textResult.characterCount,
        extractedText: textResult.extractedText,
        progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: PdfToTextStatus.error,
        errorMessage: e is PdfToTextError ? e.userMessage : 'Text extraction failed.',
      );
    }
  }

  void cancelExtraction() {
    _isCancelled = true;
  }

  Future<void> reset() async {
    await _fileManager.cleanupToolTemp('PdfToText');
    state = const PdfToTextState();
  }

  void dismissError() {
    state = state.copyWith(status: PdfToTextStatus.idle, errorMessage: null);
  }

  @override
  void dispose() {
    _fileManager.cleanupToolTemp('PdfToText');
    super.dispose();
  }
}
