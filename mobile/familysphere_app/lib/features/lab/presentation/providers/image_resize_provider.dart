import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:familysphere_app/features/lab/domain/services/image_resize_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';

// ─── STATE ───────────────────────────────────────────────────────────────────

enum ResizeStatus {
  idle,
  picking,
  processing,
  success,
  error,
}

class SelectedImage {
  final String path;
  final String name;
  final int width;
  final int height;
  final int sizeBytes;

  const SelectedImage({
    required this.path,
    required this.name,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  String get sizeLabel => LabFileManager.formatFileSize(sizeBytes);
  String get dimensionLabel => '${width} × ${height}';
}

class ImageResizeState {
  final SelectedImage? selectedImage;
  final ImageResizeMode mode;
  final double percentage; // 10 to 100
  final int? targetWidth;
  final int? targetHeight;
  final bool lockAspectRatio;
  final ImageOutputFormat format;
  final String outputFileName;
  final ResizeStatus status;
  final double progress;
  final String progressMessage;
  final String? errorMessage;
  final String? outputFilePath;
  final int? outputSizeBytes;

  const ImageResizeState({
    this.selectedImage,
    this.mode = ImageResizeMode.percentage,
    this.percentage = 50.0,
    this.targetWidth,
    this.targetHeight,
    this.lockAspectRatio = true,
    this.format = ImageOutputFormat.original,
    this.outputFileName = 'image',
    this.status = ResizeStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.errorMessage,
    this.outputFilePath,
    this.outputSizeBytes,
  });

  bool get canProcess => selectedImage != null && status == ResizeStatus.idle;

  ImageResizeState copyWith({
    SelectedImage? selectedImage,
    ImageResizeMode? mode,
    double? percentage,
    int? targetWidth,
    int? targetHeight,
    bool? lockAspectRatio,
    ImageOutputFormat? format,
    String? outputFileName,
    ResizeStatus? status,
    double? progress,
    String? progressMessage,
    String? errorMessage,
    String? outputFilePath,
    int? outputSizeBytes,
    bool clearImage = false,
  }) {
    return ImageResizeState(
      selectedImage: clearImage ? null : (selectedImage ?? this.selectedImage),
      mode: mode ?? this.mode,
      percentage: percentage ?? this.percentage,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
      format: format ?? this.format,
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

final imageResizeProvider =
    StateNotifierProvider.autoDispose<ImageResizeNotifier, ImageResizeState>((ref) {
  return ImageResizeNotifier(ref);
});

class ImageResizeNotifier extends StateNotifier<ImageResizeState> {
  ImageResizeNotifier(this._ref) : super(const ImageResizeState());

  final Ref _ref;
  final ImageResizeService _resizeService = ImageResizeService();
  final LabFileManager _fileManager = LabFileManager();
  final ImagePicker _picker = ImagePicker();
  bool _isCancelled = false;

  Future<void> pickImage() async {
    if (state.status == ResizeStatus.picking) return;

    state = state.copyWith(status: ResizeStatus.picking);

    try {
      final XFile? xFile = await _picker.pickImage(source: ImageSource.gallery);

      if (xFile == null) {
        state = state.copyWith(status: ResizeStatus.idle);
        return;
      }

      final file = File(xFile.path);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        state = state.copyWith(
          status: ResizeStatus.error,
          errorMessage: 'Unsupported image format.',
        );
        return;
      }

      state = state.copyWith(
        selectedImage: SelectedImage(
          path: xFile.path,
          name: xFile.name,
          width: decoded.width,
          height: decoded.height,
          sizeBytes: await file.length(),
        ),
        status: ResizeStatus.idle,
        outputFileName: xFile.name.split('.').first,
      );
    } catch (e) {
      state = state.copyWith(
        status: ResizeStatus.error,
        errorMessage: 'Failed to load image.',
      );
    }
  }

  void removeImage() {
    state = state.copyWith(clearImage: true, status: ResizeStatus.idle);
  }

  void setMode(ImageResizeMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setPercentage(double value) {
    state = state.copyWith(percentage: value);
  }

  void setTargetWidth(int? width) {
    state = state.copyWith(targetWidth: width);
  }

  void setTargetHeight(int? height) {
    state = state.copyWith(targetHeight: height);
  }

  void setLockAspectRatio(bool lock) {
    state = state.copyWith(lockAspectRatio: lock);
  }

  void setFormat(ImageOutputFormat format) {
    state = state.copyWith(format: format);
  }

  void setOutputFileName(String name) {
    state = state.copyWith(outputFileName: name);
  }

  Future<void> startResize() async {
    if (!state.canProcess) return;

    _isCancelled = false;
    state = state.copyWith(
      status: ResizeStatus.processing,
      progress: 0.0,
      progressMessage: 'Starting...',
    );

    try {
      final result = await _resizeService.resizeImage(
        inputFile: File(state.selectedImage!.path),
        outputFileName: state.outputFileName,
        mode: state.mode,
        format: state.format,
        percentage: state.percentage,
        targetWidth: state.targetWidth,
        targetHeight: state.targetHeight,
        lockAspectRatio: state.lockAspectRatio,
        isCancelled: () => _isCancelled,
        onProgress: (progress, statusMsg) {
          if (!mounted) return;
          state = state.copyWith(
            progress: progress,
            progressMessage: statusMsg,
          );
        },
      );

      if (!mounted) return;

      // Add to recent files
      _ref.read(labRecentFilesProvider.notifier).addFile(
        LabRecentFile(
          filePath: result.outputPath,
          fileName: result.outputPath.split(Platform.pathSeparator).last,
          sizeBytes: result.outputSizeBytes,
          toolId: 'image_resize',
          toolLabel: 'Resize Image',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(
        status: ResizeStatus.success,
        progress: 1.0,
        outputFilePath: result.outputPath,
        outputSizeBytes: result.outputSizeBytes,
      );
    } on ResizeCancelledError {
      await _fileManager.cleanupToolTemp('ResizeImage');
      if (!mounted) return;
      state = state.copyWith(status: ResizeStatus.idle);
    } on ImageResizeError catch (e) {
      await _fileManager.cleanupToolTemp('ResizeImage');
      if (!mounted) return;
      state = state.copyWith(
        status: ResizeStatus.error,
        errorMessage: e.userMessage,
      );
    } catch (e) {
      await _fileManager.cleanupToolTemp('ResizeImage');
      if (!mounted) return;
      state = state.copyWith(
        status: ResizeStatus.error,
        errorMessage: 'An unexpected error occurred.',
      );
    }
  }

  void cancelResize() {
    _isCancelled = true;
  }

  void reset() {
    state = const ImageResizeState();
  }

  void dismissError() {
    state = state.copyWith(status: ResizeStatus.idle);
  }
}
