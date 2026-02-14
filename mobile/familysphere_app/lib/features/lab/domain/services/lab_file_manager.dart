import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Manages file lifecycle for Lab tools following the 4-zone storage model:
///   Input Zone  — read-only references to user's original files
///   Temp Zone   — short-lived working copies (auto-deleted)
///   Output Zone — final processed files (user owns these)
///   Cache Zone  — thumbnails/previews (auto-managed)
class LabFileManager {
  // ─── STORAGE ZONE PATHS ────────────────────────────────────────────────────

  /// Returns the app's temp working directory for a given tool.
  /// Files here are disposable and cleaned up after every operation.
  Future<Directory> getTempDir(String toolName) async {
    final appDir = await getApplicationCacheDirectory();
    final tempDir = Directory('${appDir.path}/lab_temp/$toolName');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  /// Returns the app-internal output directory for a specific tool.
  /// Files stay here until the user explicitly saves to Downloads.
  Future<Directory> getOutputDir(String toolFolder) async {
    final baseDir = await getApplicationDocumentsDirectory();

    final outputDir = Directory(
      '${baseDir.path}/FamilySphere/Lab/$toolFolder',
    );
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir;
  }

  /// Copies a file to the public Downloads directory so it's visible
  /// in file managers. Returns the destination path.
  Future<String> saveToDownloads(String sourceFilePath, String toolFolder) async {
    final sourceFile = File(sourceFilePath);
    final fileName = sourceFilePath.split(Platform.pathSeparator).last;

    // Get public Downloads directory
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = await getDownloadsDirectory();
    }
    downloadsDir ??= await getApplicationDocumentsDirectory();

    final destDir = Directory('${downloadsDir.path}/FamilySphere/$toolFolder');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final destPath = await generateUniqueOutputPath(destDir, fileName, '.pdf');
    await sourceFile.copy(destPath);
    return destPath;
  }

  // ─── FILE NAMING ───────────────────────────────────────────────────────────

  /// Generates a unique output file name, appending (1), (2), etc.
  /// if a file with the same name already exists in the output directory.
  Future<String> generateUniqueOutputPath(
    Directory outputDir,
    String baseName,
    String extension,
  ) async {
    // Ensure extension starts with dot
    final ext = extension.startsWith('.') ? extension : '.$extension';

    // Clean the base name (remove extension if user included it)
    var cleanName = baseName;
    if (cleanName.toLowerCase().endsWith(ext.toLowerCase())) {
      cleanName = cleanName.substring(0, cleanName.length - ext.length);
    }

    // Try the original name first
    var candidate = File('${outputDir.path}/$cleanName$ext');
    if (!await candidate.exists()) {
      return candidate.path;
    }

    // Append numeric suffix
    int counter = 1;
    while (await candidate.exists()) {
      candidate = File('${outputDir.path}/$cleanName ($counter)$ext');
      counter++;
    }
    return candidate.path;
  }

  // ─── CLEANUP ───────────────────────────────────────────────────────────────

  /// Deletes all temp files for a specific tool.
  Future<void> cleanupToolTemp(String toolName) async {
    try {
      final appDir = await getApplicationCacheDirectory();
      final tempDir = Directory('${appDir.path}/lab_temp/$toolName');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {
      // Cleanup is best-effort — never throw from here
    }
  }

  /// Deletes ALL lab temp files (called on app startup).
  Future<void> cleanupAllTemp() async {
    try {
      final appDir = await getApplicationCacheDirectory();
      final labTempDir = Directory('${appDir.path}/lab_temp');
      if (await labTempDir.exists()) {
        await labTempDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup
    }
  }

  // ─── STORAGE CHECKS ────────────────────────────────────────────────────────

  /// Checks if there's enough free disk space for the operation.
  /// Requires at least [requiredBytes] × 2 (for temp copy + output).
  Future<bool> hasEnoughStorage(int requiredBytes) async {
    try {
      final dir = await getApplicationCacheDirectory();
      final stat = await dir.stat();
      // FileStat doesn't expose free space directly.
      // We use a heuristic: try to check if the path is writable
      // and the required space is reasonable ( < 200MB for mobile).
      // For a more accurate check on Android, platform channels would be needed.
      if (stat.type == FileSystemEntityType.directory) {
        // Basic sanity check: reject if total needed > 200MB
        return requiredBytes * 2 < 200 * 1024 * 1024;
      }
      return true;
    } catch (_) {
      return true; // Optimistic — actual write will fail if out of space
    }
  }

  // ─── FILE SIZE HELPERS ─────────────────────────────────────────────────────

  /// Returns the total size of all files in bytes.
  int totalFileSize(List<File> files) {
    int total = 0;
    for (final file in files) {
      total += file.lengthSync();
    }
    return total;
  }

  /// Formats bytes into a human-readable string.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
