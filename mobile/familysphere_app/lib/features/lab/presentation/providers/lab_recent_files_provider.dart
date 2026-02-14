import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// ─── MODEL ───────────────────────────────────────────────────────────────────

/// Represents a file produced by a Lab tool (local-only, not cloud).
class LabRecentFile {
  final String filePath;
  final String fileName;
  final int sizeBytes;
  final String toolId;     // e.g. 'merge_pdf', 'compress_pdf'
  final String toolLabel;  // e.g. 'Merge PDF', 'Compress PDF'
  final DateTime createdAt;

  const LabRecentFile({
    required this.filePath,
    required this.fileName,
    required this.sizeBytes,
    required this.toolId,
    required this.toolLabel,
    required this.createdAt,
  });

  /// Check if the output file still exists on disk.
  bool get fileExists => File(filePath).existsSync();

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'toolId': toolId,
        'toolLabel': toolLabel,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LabRecentFile.fromJson(Map<dynamic, dynamic> json) {
    return LabRecentFile(
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      sizeBytes: json['sizeBytes'] as int,
      toolId: json['toolId'] as String,
      toolLabel: json['toolLabel'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ─── HIVE STORAGE ────────────────────────────────────────────────────────────

class LabRecentFilesStorage {
  static const String _boxName = 'lab_recent_files';
  static const int _maxEntries = 20;

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  /// Adds a new recent file entry (most recent first).
  Future<void> addRecentFile(LabRecentFile file) async {
    final box = await _openBox();

    // Get existing entries
    final entries = _readEntries(box);

    // Remove duplicate if same path exists
    entries.removeWhere((e) => e.filePath == file.filePath);

    // Add new entry at the beginning
    entries.insert(0, file);

    // Cap at max entries
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }

    // Save
    await box.put(
      'entries',
      entries.map((e) => e.toJson()).toList(),
    );
  }

  /// Returns all recent files, most recent first.
  Future<List<LabRecentFile>> getRecentFiles() async {
    final box = await _openBox();
    final entries = _readEntries(box);

    // Filter out files that no longer exist on disk
    final valid = entries.where((e) => e.fileExists).toList();

    // If we removed any stale entries, persist the cleaned list
    if (valid.length != entries.length) {
      await box.put(
        'entries',
        valid.map((e) => e.toJson()).toList(),
      );
    }

    return valid;
  }

  /// Removes a specific entry by file path.
  Future<void> removeEntry(String filePath) async {
    final box = await _openBox();
    final entries = _readEntries(box);
    entries.removeWhere((e) => e.filePath == filePath);
    await box.put(
      'entries',
      entries.map((e) => e.toJson()).toList(),
    );
  }

  /// Clears all recent file entries.
  Future<void> clearAll() async {
    final box = await _openBox();
    await box.delete('entries');
  }

  List<LabRecentFile> _readEntries(Box box) {
    final raw = box.get('entries');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => LabRecentFile.fromJson(e as Map<dynamic, dynamic>))
        .toList();
  }
}

// ─── RIVERPOD PROVIDER ───────────────────────────────────────────────────────

final labRecentFilesProvider =
    StateNotifierProvider<LabRecentFilesNotifier, List<LabRecentFile>>((ref) {
  return LabRecentFilesNotifier();
});

class LabRecentFilesNotifier extends StateNotifier<List<LabRecentFile>> {
  LabRecentFilesNotifier() : super([]) {
    _load();
  }

  final _storage = LabRecentFilesStorage();

  Future<void> _load() async {
    state = await _storage.getRecentFiles();
  }

  /// Call this after a tool produces output successfully.
  Future<void> addFile(LabRecentFile file) async {
    await _storage.addRecentFile(file);
    state = await _storage.getRecentFiles();
  }

  /// Refresh the list (e.g. on screen focus).
  Future<void> refresh() async {
    state = await _storage.getRecentFiles();
  }

  /// Remove a specific entry.
  Future<void> remove(String filePath) async {
    await _storage.removeEntry(filePath);
    state = await _storage.getRecentFiles();
  }
}
