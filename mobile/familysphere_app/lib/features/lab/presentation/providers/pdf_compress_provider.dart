import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/pdf_compress_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── PROVIDER STATE ─────────────────────────────────────────────────────────

enum CompressStatus {
  idle,
  analyzing,
  ready,
  compressing,
  success,
  error,
}

class PdfCompressState {
  final File? inputFile;
  final int originalSize;
  final int estimatedSize;
  final CompressionLevel compressionLevel;
  final CompressStatus status;
  final double progress;
  final String? outputFilePath;
  final String? errorMessage;

  const PdfCompressState({
    this.inputFile,
    this.originalSize = 0,
    this.estimatedSize = 0,
    this.compressionLevel = CompressionLevel.medium,
    this.status = CompressStatus.idle,
    this.progress = 0.0,
    this.outputFilePath,
    this.errorMessage,
  });

  bool get isProcessing => status == CompressStatus.analyzing || status == CompressStatus.compressing;
  bool get canCompress => status == CompressStatus.ready && !isProcessing;

  PdfCompressState copyWith({
    File? inputFile,
    int? originalSize,
    int? estimatedSize,
    CompressionLevel? compressionLevel,
    CompressStatus? status,
    double? progress,
    String? outputFilePath,
    String? errorMessage,
    bool clearInput = false,
  }) {
    return PdfCompressState(
      inputFile: clearInput ? null : (inputFile ?? this.inputFile),
      originalSize: clearInput ? 0 : (originalSize ?? this.originalSize),
      estimatedSize: clearInput ? 0 : (estimatedSize ?? this.estimatedSize),
      compressionLevel: compressionLevel ?? this.compressionLevel,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputFilePath: outputFilePath ?? this.outputFilePath,
      errorMessage: errorMessage,
    );
  }
}

// ─── PROVIDER ────────────────────────────────────────────────────────────────

final pdfCompressProvider = StateNotifierProvider.autoDispose<PdfCompressNotifier, PdfCompressState>((ref) {
  return PdfCompressNotifier(ref);
});

class PdfCompressNotifier extends StateNotifier<PdfCompressState> {
  final Ref _ref;
  final PdfCompressService _service = PdfCompressService();
  final LabFileManager _fileManager = LabFileManager();
  bool _isCancelled = false;

  PdfCompressNotifier(this._ref) : super(const PdfCompressState());

  /// Pick a PDF file and trigger initial analysis.
  Future<void> pickFile() async {
    if (state.isProcessing) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final file = File(result.files.first.path!);
      await analyzeAndSetFile(file);
    } catch (e) {
      state = state.copyWith(
        status: CompressStatus.error,
        errorMessage: e is PdfCompressException ? e.userMessage : 'Could not pick file.',
      );
    }
  }

  /// Analyzes the PDF and sets the state to 'ready'.
  Future<void> analyzeAndSetFile(File file) async {
    state = state.copyWith(status: CompressStatus.analyzing, progress: 0.0);

    try {
      final analysis = await _service.analyzePdf(file);
      final estimated = _service.estimateCompressedSize(analysis.originalSize, state.compressionLevel);

      state = state.copyWith(
        inputFile: file,
        originalSize: analysis.originalSize,
        estimatedSize: estimated,
        status: CompressStatus.ready,
      );
    } catch (e) {
      state = state.copyWith(
        status: CompressStatus.error,
        errorMessage: e is PdfCompressException ? e.userMessage : 'Analysis failed.',
      );
    }
  }

  /// Updates the compression level and re-estimates the size.
  void setCompressionLevel(CompressionLevel level) {
    if (state.isProcessing) return;
    
    final estimated = state.inputFile != null 
        ? _service.estimateCompressedSize(state.originalSize, level)
        : 0;

    state = state.copyWith(
      compressionLevel: level,
      estimatedSize: estimated,
    );
  }

  /// Executes the compression.
  Future<void> startCompression() async {
    if (!state.canCompress) return;

    _isCancelled = false;
    state = state.copyWith(
      status: CompressStatus.compressing,
      progress: 0.0,
      errorMessage: null,
    );

    try {
      final String fileName = state.inputFile!.path.split(Platform.pathSeparator).last;
      final String outputName = fileName;

      final String resultPath = await _service.compressPdf(
        inputPdf: state.inputFile!,
        level: state.compressionLevel,
        outputFileName: outputName,
        onProgress: (p) => state = state.copyWith(progress: p),
        isCancelled: () => _isCancelled,
      );

      if (!mounted) return;

      // Add to recent files
      final file = File(resultPath);
      final size = await file.length();
      
      _ref.read(labRecentFilesProvider.notifier).addFile(
        LabRecentFile(
          filePath: resultPath,
          fileName: resultPath.split(Platform.pathSeparator).last,
          sizeBytes: size,
          toolId: 'pdf_compress',
          toolLabel: 'Compress PDF',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        status: CompressStatus.success,
        outputFilePath: resultPath,
        progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: CompressStatus.error,
        errorMessage: e is PdfCompressException ? e.userMessage : 'Compression failed.',
      );
    }
  }

  void cancelCompression() {
    _isCancelled = true;
  }

  /// Resets the state and triggers cleanup.
  Future<void> reset() async {
    await _fileManager.cleanupToolTemp('CompressPDF');
    state = const PdfCompressState();
  }

  @override
  void dispose() {
    _fileManager.cleanupToolTemp('CompressPDF');
    super.dispose();
  }
}
