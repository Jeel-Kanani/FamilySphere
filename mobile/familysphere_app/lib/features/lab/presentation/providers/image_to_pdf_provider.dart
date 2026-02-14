import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/image_to_pdf_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── STATE ───────────────────────────────────────────────────────────────────

enum ImageToPdfStatus {
  idle,
  picking,
  validating,
  converting,
  success,
  error,
}

class SelectedImageFile {
  final String name;
  final String path;
  final int sizeBytes;

  const SelectedImageFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  String get sizeLabel => LabFileManager.formatFileSize(sizeBytes);
}

class ImageToPdfState {
  final List<SelectedImageFile> selectedImages;
  final String outputFileName;
  final PdfPageSize pageSize;
  final PdfOrientation orientation;
  final ImageToPdfStatus status;
  final double progress;
  final String progressMessage;
  final String? errorMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;

  const ImageToPdfState({
    this.selectedImages = const [],
    this.outputFileName = 'images_to_pdf.pdf',
    this.pageSize = PdfPageSize.auto,
    this.orientation = PdfOrientation.auto,
    this.status = ImageToPdfStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.errorMessage,
    this.outputFilePath,
    this.outputSizeBytes,
  });

  bool get canConvert =>
      selectedImages.isNotEmpty && status == ImageToPdfStatus.idle;

  bool get isProcessing =>
      status == ImageToPdfStatus.validating ||
      status == ImageToPdfStatus.converting ||
      status == ImageToPdfStatus.picking;

  int get totalSizeBytes {
    int total = 0;
    for (final f in selectedImages) {
      total += f.sizeBytes;
    }
    return total;
  }

  String get totalSizeLabel => LabFileManager.formatFileSize(totalSizeBytes);

  ImageToPdfState copyWith({
    List<SelectedImageFile>? selectedImages,
    String? outputFileName,
    PdfPageSize? pageSize,
    PdfOrientation? orientation,
    ImageToPdfStatus? status,
    double? progress,
    String? progressMessage,
    String? errorMessage,
    String? outputFilePath,
    int? outputSizeBytes,
  }) {
    return ImageToPdfState(
      selectedImages: selectedImages ?? this.selectedImages,
      outputFileName: outputFileName ?? this.outputFileName,
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
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

final imageToPdfProvider =
    StateNotifierProvider.autoDispose<ImageToPdfNotifier, ImageToPdfState>((ref) {
  return ImageToPdfNotifier(ref);
});

class ImageToPdfNotifier extends StateNotifier<ImageToPdfState> {
  ImageToPdfNotifier(this._ref) : super(const ImageToPdfState());

  final Ref _ref;
  final ImageToPdfService _convertService = ImageToPdfService();
  final LabFileManager _fileManager = LabFileManager();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isCancelled = false;

  // ─── IMAGE SELECTION ──────────────────────────────────────────────────

  /// Opens image picker to select images.
  Future<void> pickImages() async {
    if (state.isProcessing) return;

    state = state.copyWith(status: ImageToPdfStatus.picking);

    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 100,
      );

      if (pickedFiles.isEmpty) {
        state = state.copyWith(status: ImageToPdfStatus.idle);
        return;
      }

      final newImages = <SelectedImageFile>[];
      for (final xFile in pickedFiles) {
        // Skip duplicates
        final alreadySelected = state.selectedImages.any(
          (f) => f.path == xFile.path,
        );
        if (alreadySelected) continue;

        final file = File(xFile.path);
        final stat = await file.stat();

        newImages.add(SelectedImageFile(
          name: xFile.name,
          path: xFile.path,
          sizeBytes: stat.size,
        ));
      }

      // Enforce max limit
      final combined = [...state.selectedImages, ...newImages];
      final capped = combined.length > ImageToPdfService.maxImages
          ? combined.sublist(0, ImageToPdfService.maxImages)
          : combined;

      // Check total size
      int totalSize = 0;
      for (final f in capped) {
        totalSize += f.sizeBytes;
      }

      if (totalSize > ImageToPdfService.maxTotalSizeBytes) {
        state = state.copyWith(
          status: ImageToPdfStatus.error,
          errorMessage:
              'Total file size (${LabFileManager.formatFileSize(totalSize)}) '
              'exceeds the ${LabFileManager.formatFileSize(ImageToPdfService.maxTotalSizeBytes)} limit.',
        );
        return;
      }

      state = state.copyWith(
        selectedImages: capped,
        status: ImageToPdfStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(
        status: ImageToPdfStatus.idle,
        errorMessage: 'Could not open image picker.',
      );
    }
  }

  /// Removes an image at the given index.
  void removeImage(int index) {
    if (state.isProcessing) return;
    if (index < 0 || index >= state.selectedImages.length) return;

    final updated = List<SelectedImageFile>.from(state.selectedImages)
      ..removeAt(index);
    state = state.copyWith(
      selectedImages: updated,
      status: ImageToPdfStatus.idle,
    );
  }

  /// Reorders images from [oldIndex] to [newIndex].
  void reorderImages(int oldIndex, int newIndex) {
    if (state.isProcessing) return;
    if (newIndex > oldIndex) newIndex--;

    final updated = List<SelectedImageFile>.from(state.selectedImages);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    state = state.copyWith(selectedImages: updated);
  }

  /// Sets the output file name.
  void setOutputName(String name) {
    if (state.isProcessing) return;
    state = state.copyWith(outputFileName: name);
  }

  /// Sets the page size.
  void setPageSize(PdfPageSize size) {
    if (state.isProcessing) return;
    state = state.copyWith(pageSize: size);
  }

  /// Sets the orientation.
  void setOrientation(PdfOrientation orientation) {
    if (state.isProcessing) return;
    state = state.copyWith(orientation: orientation);
  }

  // ─── CONVERSION ─────────────────────────────────────────────────────────

  /// Starts the image-to-PDF conversion.
  Future<void> startConversion() async {
    if (!state.canConvert) return;

    _isCancelled = false;

    state = state.copyWith(
      status: ImageToPdfStatus.validating,
      progress: 0.0,
      progressMessage: 'Validating images...',
    );

    try {
      final inputFiles =
          state.selectedImages.map((f) => File(f.path)).toList();

      final result = await _convertService.convertImagesToPdf(
        inputImages: inputFiles,
        outputFileName: state.outputFileName,
        pageSize: state.pageSize,
        orientation: state.orientation,
        isCancelled: () => _isCancelled,
        onProgress: (progress, statusMsg) {
          if (!mounted) return;
          state = state.copyWith(
            status: ImageToPdfStatus.converting,
            progress: progress,
            progressMessage: statusMsg,
          );
        },
      );

      if (!mounted) return;

      // Add to Lab recent files
      final fileName = result.outputPath.split(Platform.pathSeparator).last;
      _ref.read(labRecentFilesProvider.notifier).addFile(
        LabRecentFile(
          filePath: result.outputPath,
          fileName: fileName,
          sizeBytes: result.outputSizeBytes,
          toolId: 'image_to_pdf',
          toolLabel: 'Image to PDF',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        status: ImageToPdfStatus.success,
        progress: 1.0,
        progressMessage: 'Done!',
        outputFilePath: result.outputPath,
        outputSizeBytes: result.outputSizeBytes,
      );
    } on ConversionCancelledError {
      await _fileManager.cleanupToolTemp('ImageToPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ImageToPdfStatus.idle,
        progress: 0.0,
        progressMessage: '',
        errorMessage: 'Conversion cancelled. No files were changed.',
      );
    } on ImageToPdfError catch (e) {
      await _fileManager.cleanupToolTemp('ImageToPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ImageToPdfStatus.error,
        progress: 0.0,
        progressMessage: '',
        errorMessage: e.userMessage,
      );
    } catch (e) {
      await _fileManager.cleanupToolTemp('ImageToPDF');
      if (!mounted) return;
      state = state.copyWith(
        status: ImageToPdfStatus.error,
        progress: 0.0,
        progressMessage: '',
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Cancels an in-progress conversion.
  void cancelConversion() {
    _isCancelled = true;
  }

  /// Resets state back to idle (after viewing result).
  void reset() {
    state = const ImageToPdfState();
  }

  /// Dismisses the error and returns to idle (keeping images selected).
  void dismissError() {
    state = state.copyWith(
      status: ImageToPdfStatus.idle,
      progress: 0.0,
      progressMessage: '',
    );
  }
}
