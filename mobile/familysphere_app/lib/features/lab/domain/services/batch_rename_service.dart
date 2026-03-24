import 'dart:io';

// ─── TYPED ERRORS ────────────────────────────────────────────────────────────

abstract class BatchRenameError implements Exception {
  final String userMessage;
  const BatchRenameError(this.userMessage);
  @override
  String toString() => userMessage;
}

class RenameValidationError extends BatchRenameError {
  const RenameValidationError(super.userMessage);
}

class RenameProcessError extends BatchRenameError {
  const RenameProcessError(super.userMessage);
}

// ─── RENAME MODES ───────────────────────────────────────────────────────────

enum RenameMode {
  addPrefix('Add Prefix'),
  addSuffix('Add Suffix'),
  findReplace('Find & Replace'),
  numbering('Sequential Numbering');

  final String label;
  const RenameMode(this.label);
}

// ─── RESULT ─────────────────────────────────────────────────────────────────

class RenamePreview {
  final String originalName;
  final String newName;

  const RenamePreview({required this.originalName, required this.newName});
}

class BatchRenameResult {
  final int filesRenamed;
  final List<RenamePreview> renames;
  final Duration duration;

  const BatchRenameResult({
    required this.filesRenamed,
    required this.renames,
    required this.duration,
  });
}

// ─── BATCH RENAME SERVICE ───────────────────────────────────────────────────

class BatchRenameService {
  /// Generates a preview of what the renames would look like.
  List<RenamePreview> previewRenames({
    required List<File> files,
    required RenameMode mode,
    String prefix = '',
    String suffix = '',
    String findText = '',
    String replaceText = '',
    String numberPrefix = 'file',
    int startNumber = 1,
  }) {
    return files.asMap().entries.map((entry) {
      final index = entry.key;
      final file = entry.value;
      final originalName = file.path.split(Platform.pathSeparator).last;
      final ext = originalName.contains('.') ? '.${originalName.split('.').last}' : '';
      final baseName = originalName.contains('.')
          ? originalName.substring(0, originalName.lastIndexOf('.'))
          : originalName;

      String newName;
      switch (mode) {
        case RenameMode.addPrefix:
          newName = '$prefix$baseName$ext';
          break;
        case RenameMode.addSuffix:
          newName = '$baseName$suffix$ext';
          break;
        case RenameMode.findReplace:
          newName = '${baseName.replaceAll(findText, replaceText)}$ext';
          break;
        case RenameMode.numbering:
          final num = (startNumber + index).toString().padLeft(3, '0');
          newName = '${numberPrefix}_$num$ext';
          break;
      }

      return RenamePreview(originalName: originalName, newName: newName);
    }).toList();
  }

  /// Applies the batch rename.
  Future<BatchRenameResult> applyRenames({
    required List<File> files,
    required List<RenamePreview> previews,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (files.length != previews.length) {
      throw const RenameValidationError('File count does not match preview count.');
    }

    int renamed = 0;
    final applied = <RenamePreview>[];

    for (int i = 0; i < files.length; i++) {
      onProgress?.call(0.1 + 0.8 * (i / files.length), 'Renaming ${i + 1} of ${files.length}...');

      final file = files[i];
      if (!await file.exists()) continue;

      final dir = file.parent.path;
      final newPath = '$dir${Platform.pathSeparator}${previews[i].newName}';

      try {
        await file.rename(newPath);
        applied.add(previews[i]);
        renamed++;
      } catch (e) {
        // Skip files that can't be renamed (e.g., permission issues)
        applied.add(RenamePreview(
          originalName: previews[i].originalName,
          newName: '${previews[i].originalName} (failed)',
        ));
      }
    }

    stopwatch.stop();
    onProgress?.call(1.0, 'Done!');

    return BatchRenameResult(
      filesRenamed: renamed,
      renames: applied,
      duration: stopwatch.elapsed,
    );
  }
}
