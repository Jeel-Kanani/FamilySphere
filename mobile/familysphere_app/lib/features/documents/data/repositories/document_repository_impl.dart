import 'dart:io';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/entities/folder_entity.dart';
import 'package:familysphere_app/features/documents/domain/repositories/document_repository.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_local_datasource.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:familysphere_app/features/documents/data/models/document_model.dart';
import 'package:familysphere_app/features/documents/domain/services/offline_file_storage_service.dart';
import 'package:http/http.dart' as http;

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentRemoteDataSource remoteDataSource;
  final DocumentLocalDataSource localDataSource;
  final OfflineFileStorageService offlineFileStorageService;

  DocumentRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.offlineFileStorageService,
  });

  String _resolvedExtension(DocumentEntity document) {
    final fileUrl = document.fileUrl.toLowerCase();
    final storage = document.storagePath.toLowerCase();
    final type = document.fileType.toLowerCase();
    final title = document.title.toLowerCase();

    if (type.contains('pdf') ||
        fileUrl.endsWith('.pdf') ||
        storage.endsWith('.pdf') ||
        title.endsWith('.pdf')) {
      return 'pdf';
    }

    if (fileUrl.endsWith('.png') || title.endsWith('.png')) return 'png';
    if (fileUrl.endsWith('.gif') || title.endsWith('.gif')) return 'gif';
    if (fileUrl.endsWith('.webp') || title.endsWith('.webp')) return 'webp';
    if (fileUrl.endsWith('.jpeg') || title.endsWith('.jpeg')) return 'jpeg';
    if (fileUrl.endsWith('.jpg') || title.endsWith('.jpg')) return 'jpg';

    return 'bin';
  }

  @override
  Future<DocumentEntity> uploadDocument({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
    String? folder,
    String? memberId,
  }) async {
    return await remoteDataSource.uploadDocument(
      file: file,
      familyId: familyId,
      title: title,
      category: category,
      uploadedBy: uploadedBy,
      folder: folder,
      memberId: memberId,
    );
  }

  @override
  Future<Map<String, dynamic>> getDocuments(String familyId,
      {String? category, String? folder, String? memberId}) async {
    try {
      final result = await remoteDataSource.getDocuments(
        familyId,
        category: category,
        folder: folder,
        memberId: memberId,
      );

      final docs = (result['documents'] as List<dynamic>)
          .whereType<DocumentEntity>()
          .map(DocumentModel.fromEntity)
          .toList();

      await localDataSource.cacheDocuments(
        familyId: familyId,
        documents: docs,
        storageUsed: result['storageUsed'] as int? ?? 0,
        storageLimit: result['storageLimit'] as int? ?? 25 * 1024 * 1024 * 1024,
        category: category,
        folder: folder,
        memberId: memberId,
      );

      return {
        ...result,
        'fromCache': false,
      };
    } catch (error) {
      final cached = await localDataSource.getCachedDocuments(
        familyId: familyId,
        category: category,
        folder: folder,
        memberId: memberId,
      );

      if (cached != null) {
        return {
          ...cached,
          'fromCache': true,
        };
      }

      rethrow;
    }
  }

  @override
  Future<void> deleteDocument({
    required String documentId,
  }) async {
    await remoteDataSource.deleteDocument(
      documentId: documentId,
    );
  }

  @override
  Future<List<String>> getFolders({
    required String familyId,
    required String category,
    String? memberId,
  }) async {
    return await remoteDataSource.getFolders(
      familyId: familyId,
      category: category,
      memberId: memberId,
    );
  }

  @override
  Future<List<FolderEntity>> getFolderDetails({
    required String familyId,
    required String category,
    String? memberId,
  }) async {
    final details = await remoteDataSource.getFolderDetails(
      familyId: familyId,
      category: category,
      memberId: memberId,
    );
    return details
        .map((map) => FolderEntity(
              name: map['name'] as String,
              isBuiltIn: map['isBuiltIn'] as bool? ?? false,
              isCustom: map['isCustom'] as bool? ?? false,
              folderId: map['folderId'] as String?,
              isSystem: map['isSystem'] as bool? ?? false,
            ))
        .toList();
  }

  @override
  Future<void> createFolder({
    required String familyId,
    required String category,
    required String name,
    String? memberId,
  }) async {
    await remoteDataSource.createFolder(
      familyId: familyId,
      category: category,
      name: name,
      memberId: memberId,
    );
  }

  @override
  Future<void> deleteFolder({
    required String folderId,
    String? folderName,
    String? familyId,
    String? category,
    String? memberId,
  }) async {
    await remoteDataSource.deleteFolder(
      folderId: folderId,
      folderName: folderName,
      familyId: familyId,
      category: category,
      memberId: memberId,
    );
  }

  @override
  Future<DocumentEntity> moveDocumentToFolder({
    required String documentId,
    required String folder,
    String? memberId,
  }) async {
    return await remoteDataSource.moveDocumentToFolder(
      documentId: documentId,
      folder: folder,
      memberId: memberId,
    );
  }

  @override
  Future<String> downloadDocument(DocumentEntity document) async {
    try {
      if (document.localPath != null &&
          document.localPath!.isNotEmpty &&
          await offlineFileStorageService.exists(document.localPath)) {
        return document.localPath!;
      }

      final response = await http.get(Uri.parse(document.fileUrl));
      if (response.statusCode == 200) {
        final filePath = await offlineFileStorageService.saveEncryptedBytes(
          documentId: document.id,
          fileName: document.title,
          plainBytes: response.bodyBytes,
          extension: _resolvedExtension(document),
        );
        await localDataSource.updateOfflineAvailability(
          documentId: document.id,
          isOfflineAvailable: true,
          localPath: filePath,
        );
        return filePath;
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }

  @override
  Future<void> removeOfflineCopy(DocumentEntity document) async {
    await offlineFileStorageService.delete(document.localPath);
    await localDataSource.updateOfflineAvailability(
      documentId: document.id,
      isOfflineAvailable: false,
      localPath: null,
    );
  }

  @override
  Future<String> prepareDocumentForViewing(DocumentEntity document) async {
    try {
      if (document.localPath != null &&
          document.localPath!.isNotEmpty &&
          await offlineFileStorageService.exists(document.localPath)) {
        return offlineFileStorageService.materializeReadableCopy(
          sourcePath: document.localPath!,
          documentId: document.id,
          fileName: document.title,
          extension: _resolvedExtension(document),
        );
      }

      final response = await http.get(Uri.parse(document.fileUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file for viewing');
      }

      return offlineFileStorageService.saveTemporaryReadableBytes(
        documentId: '${document.id}_view_temp',
        fileName: document.title,
        plainBytes: response.bodyBytes,
        extension: _resolvedExtension(document),
      );
    } catch (e) {
      throw Exception('Document view preparation failed: $e');
    }
  }

  @override
  Future<List<DocumentEntity>> getTrashedDocuments({
    required String familyId,
  }) async {
    final documents =
        await remoteDataSource.getTrashedDocuments(familyId: familyId);
    return documents;
  }

  @override
  Future<DocumentEntity> restoreDocument({
    required String documentId,
  }) async {
    return await remoteDataSource.restoreDocument(documentId: documentId);
  }

  @override
  Future<void> permanentlyDeleteDocument({
    required String documentId,
  }) async {
    await remoteDataSource.permanentlyDeleteDocument(documentId: documentId);
  }

  @override
  Future<Map<String, dynamic>> getOcrStatus({
    required String documentId,
  }) async {
    return await remoteDataSource.getOcrStatus(documentId: documentId);
  }

  @override
  Future<dynamic> getDocumentIntelligence({
    required String documentId,
  }) async {
    return await remoteDataSource.getDocumentIntelligence(
        documentId: documentId);
  }

  @override
  Future<void> confirmDocumentType({
    required String documentId,
    required String docType,
  }) async {
    await remoteDataSource.confirmDocumentType(
      documentId: documentId,
      docType: docType,
    );
  }
}
