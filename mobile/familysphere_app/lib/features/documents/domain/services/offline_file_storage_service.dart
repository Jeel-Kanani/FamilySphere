import 'dart:io';

import 'package:familysphere_app/features/documents/domain/services/document_encryption_service.dart';
import 'package:path_provider/path_provider.dart';

class OfflineFileStorageService {
  final DocumentEncryptionService _encryptionService;

  OfflineFileStorageService({
    required DocumentEncryptionService encryptionService,
  }) : _encryptionService = encryptionService;

  Future<Directory> _offlineDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/offline_documents');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _tempViewDir() async {
    final baseDir = await getTemporaryDirectory();
    final dir = Directory('${baseDir.path}/offline_document_views');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  Future<String> saveEncryptedBytes({
    required String documentId,
    required String fileName,
    required List<int> plainBytes,
    required String extension,
  }) async {
    final dir = await _offlineDir();
    final path =
        '${dir.path}/${_sanitize(documentId)}_${_sanitize(fileName)}.$extension.fsenc';
    final encryptedBytes = await _encryptionService.encrypt(plainBytes);
    final file = File(path);
    await file.writeAsBytes(encryptedBytes, flush: true);
    return file.path;
  }

  Future<String> materializeReadableCopy({
    required String sourcePath,
    required String documentId,
    required String fileName,
    required String extension,
  }) async {
    final encryptedFile = File(sourcePath);
    if (!await encryptedFile.exists()) {
      throw Exception('Offline document copy is missing.');
    }

    final encryptedBytes = await encryptedFile.readAsBytes();
    final plainBytes = await _encryptionService.decrypt(encryptedBytes);
    final tempDir = await _tempViewDir();
    final readablePath =
        '${tempDir.path}/${_sanitize(documentId)}_${_sanitize(fileName)}.$extension';
    final tempFile = File(readablePath);
    await tempFile.writeAsBytes(plainBytes, flush: true);
    return tempFile.path;
  }

  Future<String> saveTemporaryReadableBytes({
    required String documentId,
    required String fileName,
    required List<int> plainBytes,
    required String extension,
  }) async {
    final tempDir = await _tempViewDir();
    final readablePath =
        '${tempDir.path}/${_sanitize(documentId)}_${_sanitize(fileName)}.$extension';
    final tempFile = File(readablePath);
    await tempFile.writeAsBytes(plainBytes, flush: true);
    return tempFile.path;
  }

  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }

  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
