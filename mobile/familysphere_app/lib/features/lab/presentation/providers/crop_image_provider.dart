import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../domain/services/crop_image_service.dart';
import '../providers/lab_recent_files_provider.dart';

class CropImageState {
  final File? imageFile;
  final bool isLoading;
  final String? error;
  final double cropX;
  final double cropY;
  final double cropWidth;
  final double cropHeight;
  final int rotation;
  final bool flipHorizontal;
  final bool flipVertical;
  final double? aspectRatio;
  final ImageOutputFormat outputFormat;
  final String outputFileName;
  final double processingProgress;
  final String processingStatus;
  final int? imageWidth;
  final int? imageHeight;

  CropImageState({
    this.imageFile,
    this.isLoading = false,
    this.error,
    this.cropX = 0.1,
    this.cropY = 0.1,
    this.cropWidth = 0.8,
    this.cropHeight = 0.8,
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.aspectRatio,
    this.outputFormat = ImageOutputFormat.original,
    this.outputFileName = 'image.jpg',
    this.processingProgress = 0,
    this.processingStatus = '',
    this.imageWidth,
    this.imageHeight,
  });

  CropImageState copyWith({
    File? imageFile,
    bool? isLoading,
    String? error,
    double? cropX,
    double? cropY,
    double? cropWidth,
    double? cropHeight,
    int? rotation,
    bool? flipHorizontal,
    bool? flipVertical,
    double? aspectRatio,
    ImageOutputFormat? outputFormat,
    String? outputFileName,
    double? processingProgress,
    String? processingStatus,
    int? imageWidth,
    int? imageHeight,
  }) {
    return CropImageState(
      imageFile: imageFile ?? this.imageFile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      cropX: cropX ?? this.cropX,
      cropY: cropY ?? this.cropY,
      cropWidth: cropWidth ?? this.cropWidth,
      cropHeight: cropHeight ?? this.cropHeight,
      rotation: rotation ?? this.rotation,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      aspectRatio: aspectRatio != undefined ? aspectRatio : this.aspectRatio,
      outputFormat: outputFormat ?? this.outputFormat,
      outputFileName: outputFileName ?? this.outputFileName,
      processingProgress: processingProgress ?? this.processingProgress,
      processingStatus: processingStatus ?? this.processingStatus,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }
}

// undefined trick for copyWith with nullable fields
const undefined = Object();

class CropImageNotifier extends StateNotifier<CropImageState> {
  final CropImageService _service;
  final Ref _ref;

  CropImageNotifier(this._service, this._ref) : super(CropImageState());

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      state = state.copyWith(
        imageFile: file,
        outputFileName: pickedFile.name,
        imageWidth: image?.width,
        imageHeight: image?.height,
      );
    }
  }

  Future<void> setImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    state = state.copyWith(
      imageFile: file,
      outputFileName: file.path.split(Platform.pathSeparator).last,
      imageWidth: image?.width,
      imageHeight: image?.height,
    );
  }

  void updateCrop(double x, double y, double w, double h) {
    state = state.copyWith(cropX: x, cropY: y, cropWidth: w, cropHeight: h);
  }

  void rotate() {
    state = state.copyWith(rotation: (state.rotation + 90) % 360);
  }

  void flipHorizontal() {
    state = state.copyWith(flipHorizontal: !state.flipHorizontal);
  }

  void flipVertical() {
    state = state.copyWith(flipVertical: !state.flipVertical);
  }

  void setAspectRatio(double? ratio) {
    state = state.copyWith(aspectRatio: ratio);
    // When aspect ratio changes, we might want to adjust the crop box immediately
    // but for now we'll let the UI handle it or provide a helper
  }

  void setOutputFormat(ImageOutputFormat format) {
    state = state.copyWith(outputFormat: format);
  }

  void setOutputFileName(String name) {
    state = state.copyWith(outputFileName: name);
  }

  Future<String?> processImage() async {
    if (state.imageFile == null) return null;

    state = state.copyWith(
      isLoading: true,
      error: null,
      processingProgress: 0,
      processingStatus: 'Validation Phase...',
    );

    try {
      final result = await _service.processImage(
        inputFile: state.imageFile!,
        outputFileName: state.outputFileName,
        format: state.outputFormat,
        cropX: state.cropX,
        cropY: state.cropY,
        cropWidth: state.cropWidth,
        cropHeight: state.cropHeight,
        rotation: state.rotation,
        flipHorizontal: state.flipHorizontal,
        flipVertical: state.flipVertical,
        onProgress: (progress, status) {
          state = state.copyWith(
            processingProgress: progress,
            processingStatus: status,
          );
        },
      );

      // Add to recent files
      _ref.read(labRecentFilesProvider.notifier).addFile(
        LabRecentFile(
          fileName: result.outputPath.split(Platform.pathSeparator).last,
          filePath: result.outputPath,
          sizeBytes: result.outputSizeBytes,
          toolId: 'crop_image',
          toolLabel: 'Crop & Rotate',
          createdAt: DateTime.now(),
        ),
      );

      state = state.copyWith(isLoading: false);
      return result.outputPath;
    } on CropImageError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.userMessage,
        processingStatus: 'Failed',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred.',
        processingStatus: 'Error',
      );
      return null;
    }
  }

  void reset() {
    state = CropImageState(imageFile: state.imageFile, outputFileName: state.outputFileName);
  }
}

final cropImageServiceProvider = Provider((ref) => CropImageService());

final cropImageProvider = StateNotifierProvider<CropImageNotifier, CropImageState>((ref) {
  final service = ref.watch(cropImageServiceProvider);
  return CropImageNotifier(service, ref);
});
