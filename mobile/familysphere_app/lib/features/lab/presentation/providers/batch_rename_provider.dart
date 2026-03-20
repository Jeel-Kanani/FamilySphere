import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/features/lab/domain/services/batch_rename_service.dart';

enum BatchRenameStatus { idle, picking, ready, processing, success, error }

class BatchRenameState {
  final List<File> files;
  final List<String> fileNames;
  final RenameMode mode;
  final String prefix;
  final String suffix;
  final String findText;
  final String replaceText;
  final String numberPrefix;
  final int startNumber;
  final BatchRenameStatus status;
  final double progress;
  final String progressMessage;
  final List<RenamePreview> previews;
  final int? filesRenamed;
  final String? errorMessage;

  const BatchRenameState({
    this.files = const [],
    this.fileNames = const [],
    this.mode = RenameMode.addPrefix,
    this.prefix = '',
    this.suffix = '',
    this.findText = '',
    this.replaceText = '',
    this.numberPrefix = 'file',
    this.startNumber = 1,
    this.status = BatchRenameStatus.idle,
    this.progress = 0.0,
    this.progressMessage = '',
    this.previews = const [],
    this.filesRenamed,
    this.errorMessage,
  });

  bool get isProcessing => status == BatchRenameStatus.picking || status == BatchRenameStatus.processing;
  bool get canProcess => status == BatchRenameStatus.ready && files.isNotEmpty;

  BatchRenameState copyWith({
    List<File>? files, List<String>? fileNames, RenameMode? mode,
    String? prefix, String? suffix, String? findText, String? replaceText,
    String? numberPrefix, int? startNumber, BatchRenameStatus? status,
    double? progress, String? progressMessage, List<RenamePreview>? previews,
    int? filesRenamed, String? errorMessage, bool clearAll = false,
  }) {
    return BatchRenameState(
      files: clearAll ? [] : (files ?? this.files),
      fileNames: clearAll ? [] : (fileNames ?? this.fileNames),
      mode: mode ?? this.mode,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
      findText: findText ?? this.findText,
      replaceText: replaceText ?? this.replaceText,
      numberPrefix: numberPrefix ?? this.numberPrefix,
      startNumber: startNumber ?? this.startNumber,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      previews: clearAll ? [] : (previews ?? this.previews),
      filesRenamed: clearAll ? null : (filesRenamed ?? this.filesRenamed),
      errorMessage: errorMessage,
    );
  }
}

final batchRenameProvider = StateNotifierProvider.autoDispose<BatchRenameNotifier, BatchRenameState>((ref) {
  return BatchRenameNotifier();
});

class BatchRenameNotifier extends StateNotifier<BatchRenameState> {
  final BatchRenameService _service = BatchRenameService();

  BatchRenameNotifier() : super(const BatchRenameState());

  Future<void> pickFiles() async {
    if (state.isProcessing) return;
    state = state.copyWith(status: BatchRenameStatus.picking);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: state.files.isNotEmpty ? BatchRenameStatus.ready : BatchRenameStatus.idle);
        return;
      }
      final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      final names = result.files.where((f) => f.path != null).map((f) => f.name).toList();
      state = state.copyWith(files: files, fileNames: names, status: BatchRenameStatus.ready);
      _updatePreviews();
    } catch (e) {
      state = state.copyWith(status: BatchRenameStatus.error, errorMessage: 'Could not pick files.');
    }
  }

  void setMode(RenameMode mode) {
    if (!state.isProcessing) {
      state = state.copyWith(mode: mode);
      _updatePreviews();
    }
  }

  void setPrefix(String v) { state = state.copyWith(prefix: v); _updatePreviews(); }
  void setSuffix(String v) { state = state.copyWith(suffix: v); _updatePreviews(); }
  void setFindText(String v) { state = state.copyWith(findText: v); _updatePreviews(); }
  void setReplaceText(String v) { state = state.copyWith(replaceText: v); _updatePreviews(); }
  void setNumberPrefix(String v) { state = state.copyWith(numberPrefix: v); _updatePreviews(); }
  void setStartNumber(int v) { state = state.copyWith(startNumber: v); _updatePreviews(); }

  void _updatePreviews() {
    if (state.files.isEmpty) return;
    final previews = _service.previewRenames(
      files: state.files, mode: state.mode,
      prefix: state.prefix, suffix: state.suffix,
      findText: state.findText, replaceText: state.replaceText,
      numberPrefix: state.numberPrefix, startNumber: state.startNumber,
    );
    state = state.copyWith(previews: previews);
  }

  Future<void> applyRenames() async {
    if (!state.canProcess) return;
    state = state.copyWith(status: BatchRenameStatus.processing, progress: 0.0, errorMessage: null);
    try {
      final result = await _service.applyRenames(
        files: state.files, previews: state.previews,
        onProgress: (p, msg) { if (mounted) state = state.copyWith(progress: p, progressMessage: msg); },
      );
      if (!mounted) return;
      state = state.copyWith(status: BatchRenameStatus.success, filesRenamed: result.filesRenamed, progress: 1.0);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(status: BatchRenameStatus.error,
          errorMessage: e is BatchRenameError ? e.userMessage : 'Rename failed.');
    }
  }

  Future<void> reset() async { state = const BatchRenameState(); }
  void dismissError() { state = state.copyWith(status: state.files.isNotEmpty ? BatchRenameStatus.ready : BatchRenameStatus.idle, errorMessage: null); }
}
