import 'dart:io';

import 'package:familysphere_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_sync_local_datasource.dart';
import 'package:familysphere_app/features/documents/data/models/document_model.dart';
import 'package:familysphere_app/features/documents/data/models/document_sync_job_model.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/services/offline_file_storage_service.dart';

class DocumentSyncSnapshot {
  final List<DocumentEntity> pendingUploads;
  final Set<String> pendingDeleteIds;
  final Map<String, String> pendingMoveFolders;
  final Set<String> failedDocumentIds;
  final Map<String, String> syncErrorsByDocumentId;
  final Map<String, String> syncJobTypesByDocumentId;
  final int pendingJobCount;
  final int failedJobCount;

  const DocumentSyncSnapshot({
    required this.pendingUploads,
    required this.pendingDeleteIds,
    required this.pendingMoveFolders,
    required this.failedDocumentIds,
    required this.syncErrorsByDocumentId,
    required this.syncJobTypesByDocumentId,
    required this.pendingJobCount,
    required this.failedJobCount,
  });
}

class DocumentSyncEngineService {
  static const int _maxRetriesBeforeFailure = 3;
  final DocumentSyncLocalDataSource _syncLocalDataSource;
  final DocumentRemoteDataSource _remoteDataSource;
  final OfflineFileStorageService _offlineFileStorageService;

  DocumentSyncEngineService({
    required DocumentSyncLocalDataSource syncLocalDataSource,
    required DocumentRemoteDataSource remoteDataSource,
    required OfflineFileStorageService offlineFileStorageService,
  })  : _syncLocalDataSource = syncLocalDataSource,
        _remoteDataSource = remoteDataSource,
        _offlineFileStorageService = offlineFileStorageService;

  String _jobId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _extensionFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.jpg')) return 'jpg';
    return 'bin';
  }

  String _fileTypeFromPath(String path) {
    final ext = _extensionFromPath(path);
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  bool _isTerminalConflictError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('document not found') ||
        normalized.contains('folder not found') ||
        normalized.contains('not allowed') ||
        normalized.contains('not authorized') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized');
  }

  String _normalizeSyncError(DocumentSyncJobModel job, Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (!_isTerminalConflictError(message)) {
      return message;
    }

    switch (job.type) {
      case 'move':
        if (message.toLowerCase().contains('document not found')) {
          return 'Move conflict: this document no longer exists on the server.';
        }
        if (message.toLowerCase().contains('folder not found')) {
          return 'Move conflict: the destination folder no longer exists on the server.';
        }
        return 'Move conflict: this change can no longer be applied on the server.';
      case 'upload':
        return 'Upload conflict: this pending upload is no longer allowed for the current account or family.';
      case 'delete':
        return 'Delete conflict: this delete request can no longer be applied from this device.';
      default:
        return message;
    }
  }

  Future<DocumentEntity> queueUpload({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
    String? folder,
    String? memberId,
  }) async {
    final localId = _jobId('local-doc');
    final encryptedPath = await _offlineFileStorageService.saveEncryptedBytes(
      documentId: localId,
      fileName: title,
      plainBytes: await file.readAsBytes(),
      extension: _extensionFromPath(file.path),
    );

    final localDocument = DocumentModel(
      id: localId,
      familyId: familyId,
      title: title,
      category: category,
      folder: folder ?? 'General',
      memberId: memberId,
      fileUrl: '',
      fileType: _fileTypeFromPath(file.path),
      sizeBytes: await file.length(),
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now(),
      storagePath: encryptedPath,
      localPath: encryptedPath,
      isOfflineAvailable: false,
      syncStatus: 'pending_upload',
    );

    final job = DocumentSyncJobModel(
      id: _jobId('upload'),
      familyId: familyId,
      type: 'upload',
      createdAt: DateTime.now(),
      payload: {
        'document': localDocument.toJson(),
        'title': title,
        'category': category,
        'folder': folder ?? 'General',
        'memberId': memberId,
        'uploadedBy': uploadedBy,
        'sourcePath': encryptedPath,
        'extension': _extensionFromPath(file.path),
      },
    );

    await _syncLocalDataSource.saveJob(job);
    return localDocument;
  }

  Future<void> queueDelete({
    required String familyId,
    required String documentId,
  }) async {
    final job = DocumentSyncJobModel(
      id: _jobId('delete'),
      familyId: familyId,
      type: 'delete',
      createdAt: DateTime.now(),
      payload: {
        'documentId': documentId,
      },
    );
    await _syncLocalDataSource.saveJob(job);
  }

  Future<void> queueMove({
    required String familyId,
    required DocumentEntity document,
    required String folder,
    String? memberId,
  }) async {
    final existingMoveJob =
        await _syncLocalDataSource.findMoveJobForDocument(document.id);
    final payload = {
      'documentId': document.id,
      'folder': folder,
      if (memberId != null) 'memberId': memberId,
      'document': DocumentModel.fromEntity(
        document.copyWith(
          folder: folder,
          syncStatus: 'pending_move',
        ),
      ).toJson(),
    };

    final job = DocumentSyncJobModel(
      id: existingMoveJob?.id ?? _jobId('move'),
      familyId: familyId,
      type: 'move',
      createdAt: existingMoveJob?.createdAt ?? DateTime.now(),
      retryCount: existingMoveJob?.retryCount ?? 0,
      payload: payload,
      lastError: existingMoveJob?.lastError,
    );
    await _syncLocalDataSource.saveJob(job);
  }

  Future<bool> updatePendingUploadFolder({
    required String localDocumentId,
    required String folder,
    String? memberId,
  }) async {
    final jobs = await _syncLocalDataSource.getAllJobs();
    for (final job in jobs) {
      if (job.type != 'upload') continue;
      final docJson = job.payload['document'];
      if (docJson is! Map) continue;
      final document =
          DocumentModel.fromJson(Map<String, dynamic>.from(docJson));
      if (document.id != localDocumentId) continue;

      final updatedDocument = DocumentModel.fromEntity(
        document.copyWith(
          folder: folder,
          syncStatus: 'pending_upload',
        ),
      );

      await _syncLocalDataSource.saveJob(
        job.copyWith(
          payload: {
            ...job.payload,
            'folder': folder,
            if (memberId != null) 'memberId': memberId,
            'document': updatedDocument.toJson(),
          },
          lastError: null,
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> cancelPendingUpload(String localDocumentId) async {
    final jobs = await _syncLocalDataSource.getAllJobs();
    for (final job in jobs) {
      if (job.type != 'upload') continue;
      final docJson = job.payload['document'];
      if (docJson is! Map) continue;
      final document =
          DocumentModel.fromJson(Map<String, dynamic>.from(docJson));
      if (document.id != localDocumentId) continue;

      await _offlineFileStorageService
          .delete(job.payload['sourcePath']?.toString());
      await _syncLocalDataSource.removeJob(job.id);
      break;
    }
  }

  Future<void> retryFailedJobs(String familyId) async {
    final failedJobs = await _syncLocalDataSource.getFailedJobsForFamily(
      familyId,
      _maxRetriesBeforeFailure,
    );

    for (final job in failedJobs) {
      await _syncLocalDataSource.saveJob(
        job.copyWith(
          retryCount: 0,
          lastError: null,
        ),
      );
    }

    await processPendingJobs(familyId);
  }

  Future<void> clearFailedJobs(String familyId) async {
    final failedJobs = await _syncLocalDataSource.getFailedJobsForFamily(
      familyId,
      _maxRetriesBeforeFailure,
    );

    for (final job in failedJobs) {
      await _clearJob(job);
    }
  }

  Future<void> retryFailedJobForDocument({
    required String familyId,
    required String documentId,
  }) async {
    final jobs = await _syncLocalDataSource.getJobsForFamily(familyId);
    final matchingJobs = jobs.where((job) {
      if (job.retryCount < _maxRetriesBeforeFailure) return false;
      if (job.type == 'upload') {
        final docJson = job.payload['document'];
        if (docJson is! Map) return false;
        final document =
            DocumentModel.fromJson(Map<String, dynamic>.from(docJson));
        return document.id == documentId;
      }
      return job.payload['documentId']?.toString() == documentId;
    }).toList();

    for (final job in matchingJobs) {
      await _syncLocalDataSource.saveJob(
        job.copyWith(
          retryCount: 0,
          lastError: null,
        ),
      );
    }

    await processPendingJobs(familyId);
  }

  Future<void> clearFailedJobForDocument({
    required String familyId,
    required String documentId,
  }) async {
    final jobs = await _syncLocalDataSource.getJobsForFamily(familyId);
    final matchingJobs = jobs.where((job) {
      if (job.retryCount < _maxRetriesBeforeFailure) return false;
      if (job.type == 'upload') {
        final docJson = job.payload['document'];
        if (docJson is! Map) return false;
        final document =
            DocumentModel.fromJson(Map<String, dynamic>.from(docJson));
        return document.id == documentId;
      }
      return job.payload['documentId']?.toString() == documentId;
    }).toList();

    for (final job in matchingJobs) {
      await _clearJob(job);
    }
  }

  Future<DocumentSyncSnapshot> snapshotForFamily(String familyId) async {
    final jobs = await _syncLocalDataSource.getJobsForFamily(familyId);
    final pendingUploads = <DocumentEntity>[];
    final pendingDeleteIds = <String>{};
    final pendingMoveFolders = <String, String>{};
    final failedDocumentIds = <String>{};
    final syncErrorsByDocumentId = <String, String>{};
    final syncJobTypesByDocumentId = <String, String>{};
    var failedJobCount = 0;

    for (final job in jobs) {
      final isFailed = job.retryCount >= _maxRetriesBeforeFailure;
      if (isFailed) {
        failedJobCount++;
      }

      if (job.type == 'upload') {
        final docJson = job.payload['document'];
        if (docJson is Map) {
          final uploadDocument =
              DocumentModel.fromJson(Map<String, dynamic>.from(docJson));
          if (isFailed) {
            failedDocumentIds.add(uploadDocument.id);
            syncJobTypesByDocumentId[uploadDocument.id] = job.type;
            if ((job.lastError ?? '').trim().isNotEmpty) {
              syncErrorsByDocumentId[uploadDocument.id] = job.lastError!.trim();
            }
          }
          pendingUploads.add(
            isFailed
                ? uploadDocument.copyWith(syncStatus: 'sync_failed')
                : uploadDocument,
          );
        }
      } else if (job.type == 'delete') {
        final documentId = job.payload['documentId']?.toString();
        if (documentId != null && documentId.isNotEmpty) {
          pendingDeleteIds.add(documentId);
        }
      } else if (job.type == 'move') {
        final documentId = job.payload['documentId']?.toString();
        final folder = job.payload['folder']?.toString();
        if (documentId != null &&
            documentId.isNotEmpty &&
            folder != null &&
            folder.isNotEmpty) {
          pendingMoveFolders[documentId] = folder;
          if (isFailed) {
            failedDocumentIds.add(documentId);
            syncJobTypesByDocumentId[documentId] = job.type;
            if ((job.lastError ?? '').trim().isNotEmpty) {
              syncErrorsByDocumentId[documentId] = job.lastError!.trim();
            }
          }
        }
      }
    }

    return DocumentSyncSnapshot(
      pendingUploads: pendingUploads,
      pendingDeleteIds: pendingDeleteIds,
      pendingMoveFolders: pendingMoveFolders,
      failedDocumentIds: failedDocumentIds,
      syncErrorsByDocumentId: syncErrorsByDocumentId,
      syncJobTypesByDocumentId: syncJobTypesByDocumentId,
      pendingJobCount: jobs.length,
      failedJobCount: failedJobCount,
    );
  }

  Future<void> processPendingJobs(String familyId) async {
    final jobs = await _syncLocalDataSource.getJobsForFamily(familyId);
    for (final job in jobs) {
      if (job.retryCount >= _maxRetriesBeforeFailure) {
        continue;
      }

      try {
        if (job.type == 'upload') {
          await _processUploadJob(job);
        } else if (job.type == 'delete') {
          await _processDeleteJob(job);
        } else if (job.type == 'move') {
          await _processMoveJob(job);
        }
        await _syncLocalDataSource.removeJob(job.id);
      } catch (error) {
        final normalizedMessage = _normalizeSyncError(job, error);
        final terminalConflict = _isTerminalConflictError(normalizedMessage);
        await _syncLocalDataSource.saveJob(
          job.copyWith(
            retryCount: terminalConflict
                ? _maxRetriesBeforeFailure
                : job.retryCount + 1,
            lastError: normalizedMessage,
          ),
        );
        break;
      }
    }
  }

  Future<void> _processUploadJob(DocumentSyncJobModel job) async {
    final sourcePath = job.payload['sourcePath']?.toString();
    final docJson = job.payload['document'];
    if (sourcePath == null || docJson is! Map) {
      throw Exception('Upload sync job is malformed.');
    }

    final localDoc = DocumentModel.fromJson(Map<String, dynamic>.from(docJson));
    final tempPath = await _offlineFileStorageService.materializeReadableCopy(
      sourcePath: sourcePath,
      documentId: localDoc.id,
      fileName: localDoc.title,
      extension: job.payload['extension']?.toString() ?? 'bin',
    );

    try {
      await _remoteDataSource.uploadDocument(
        file: File(tempPath),
        familyId: localDoc.familyId,
        title: job.payload['title']?.toString() ?? localDoc.title,
        category: job.payload['category']?.toString() ?? localDoc.category,
        uploadedBy:
            job.payload['uploadedBy']?.toString() ?? localDoc.uploadedBy,
        folder: job.payload['folder']?.toString(),
        memberId: job.payload['memberId']?.toString(),
      );
    } finally {
      await _offlineFileStorageService.delete(tempPath);
      await _offlineFileStorageService.delete(sourcePath);
    }
  }

  Future<void> _processDeleteJob(DocumentSyncJobModel job) async {
    final documentId = job.payload['documentId']?.toString();
    if (documentId == null || documentId.isEmpty) {
      throw Exception('Delete sync job is malformed.');
    }
    try {
      await _remoteDataSource.deleteDocument(documentId: documentId);
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('document not found')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _processMoveJob(DocumentSyncJobModel job) async {
    final documentId = job.payload['documentId']?.toString();
    final folder = job.payload['folder']?.toString();
    if (documentId == null ||
        documentId.isEmpty ||
        folder == null ||
        folder.isEmpty) {
      throw Exception('Move sync job is malformed.');
    }

    await _remoteDataSource.moveDocumentToFolder(
      documentId: documentId,
      folder: folder,
      memberId: job.payload['memberId']?.toString(),
    );
  }

  Future<void> _clearJob(DocumentSyncJobModel job) async {
    if (job.type == 'upload') {
      await _offlineFileStorageService
          .delete(job.payload['sourcePath']?.toString());
    }
    await _syncLocalDataSource.removeJob(job.id);
  }
}
