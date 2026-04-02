import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/entities/folder_entity.dart';
import 'package:familysphere_app/features/documents/domain/usecases/upload_document.dart';
import 'package:familysphere_app/features/documents/domain/usecases/get_documents.dart';
import 'package:familysphere_app/features/documents/domain/usecases/delete_document.dart';
import 'package:familysphere_app/features/documents/domain/usecases/download_document.dart';
import 'package:familysphere_app/features/documents/domain/usecases/prepare_document_for_viewing.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_local_datasource.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_sync_local_datasource.dart';
import 'package:familysphere_app/features/documents/data/datasources/sync_history_local_datasource.dart';
import 'package:familysphere_app/features/documents/data/models/sync_history_entry_model.dart';
import 'package:familysphere_app/features/documents/data/repositories/document_repository_impl.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:familysphere_app/features/documents/domain/services/document_encryption_service.dart';
import 'package:familysphere_app/features/documents/domain/services/offline_file_storage_service.dart';
import 'package:familysphere_app/features/documents/domain/services/document_sync_engine_service.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/core/providers/network_status_provider.dart';

// --- Data Source Provider ---
final documentRemoteDataSourceProvider = Provider((ref) {
  return DocumentRemoteDataSource(apiClient: ref.read(apiClientProvider));
});

final documentLocalDataSourceProvider = Provider((ref) {
  return DocumentLocalDataSource();
});

final documentSyncLocalDataSourceProvider = Provider((ref) {
  return DocumentSyncLocalDataSource();
});

final syncHistoryLocalDataSourceProvider = Provider((ref) {
  return SyncHistoryLocalDataSource();
});

final documentEncryptionServiceProvider = Provider((ref) {
  return DocumentEncryptionService();
});

final offlineFileStorageServiceProvider = Provider((ref) {
  return OfflineFileStorageService(
    encryptionService: ref.read(documentEncryptionServiceProvider),
  );
});

final documentSyncEngineServiceProvider = Provider((ref) {
  return DocumentSyncEngineService(
    syncLocalDataSource: ref.read(documentSyncLocalDataSourceProvider),
    remoteDataSource: ref.read(documentRemoteDataSourceProvider),
    offlineFileStorageService: ref.read(offlineFileStorageServiceProvider),
  );
});

// --- Repository Provider ---
final documentRepositoryProvider = Provider((ref) {
  return DocumentRepositoryImpl(
    remoteDataSource: ref.read(documentRemoteDataSourceProvider),
    localDataSource: ref.read(documentLocalDataSourceProvider),
    offlineFileStorageService: ref.read(offlineFileStorageServiceProvider),
  );
});

// --- Use Case Providers ---
final uploadDocumentUseCaseProvider = Provider((ref) {
  return UploadDocument(ref.read(documentRepositoryProvider));
});

final getDocumentsUseCaseProvider = Provider((ref) {
  return GetDocuments(ref.read(documentRepositoryProvider));
});

final deleteDocumentUseCaseProvider = Provider((ref) {
  return DeleteDocument(ref.read(documentRepositoryProvider));
});

final downloadDocumentUseCaseProvider = Provider((ref) {
  return DownloadDocument(ref.read(documentRepositoryProvider));
});

final prepareDocumentForViewingUseCaseProvider = Provider((ref) {
  return PrepareDocumentForViewing(ref.read(documentRepositoryProvider));
});

// --- State ---
class DocumentState {
  final List<DocumentEntity> documents;
  final List<String> folders;
  final Map<String, List<String>> foldersByQueryCache;
  final Map<String, List<FolderEntity>> folderDetailsCache;
  final bool isLoading;
  final String? error;
  final double? uploadProgress;
  final String? lastUploadedDocId; // Phase 6 – docId for OCR polling
  final int storageUsed;
  final int storageLimit;
  final DateTime? lastStorageSync;
  final bool showingCachedData;
  final int pendingSyncJobs;
  final int failedSyncJobs;
  final Map<String, String> syncErrorsByDocumentId;
  final Map<String, String> syncJobTypesByDocumentId;
  final List<SyncHistoryEntryModel> syncHistory;

  const DocumentState({
    this.documents = const [],
    this.folders = const [],
    this.foldersByQueryCache = const {},
    this.folderDetailsCache = const {},
    this.isLoading = false,
    this.error,
    this.uploadProgress,
    this.lastUploadedDocId,
    this.storageUsed = 0,
    this.storageLimit = 25 * 1024 * 1024 * 1024, // 25 GB default
    this.lastStorageSync,
    this.showingCachedData = false,
    this.pendingSyncJobs = 0,
    this.failedSyncJobs = 0,
    this.syncErrorsByDocumentId = const {},
    this.syncJobTypesByDocumentId = const {},
    this.syncHistory = const [],
  });

  factory DocumentState.initial() => const DocumentState();

  DocumentState copyWith({
    List<DocumentEntity>? documents,
    List<String>? folders,
    Map<String, List<String>>? foldersByQueryCache,
    Map<String, List<FolderEntity>>? folderDetailsCache,
    bool? isLoading,
    String? error,
    double? uploadProgress,
    String? lastUploadedDocId,
    int? storageUsed,
    int? storageLimit,
    DateTime? lastStorageSync,
    bool? showingCachedData,
    int? pendingSyncJobs,
    int? failedSyncJobs,
    Map<String, String>? syncErrorsByDocumentId,
    Map<String, String>? syncJobTypesByDocumentId,
    List<SyncHistoryEntryModel>? syncHistory,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      folders: folders ?? this.folders,
      foldersByQueryCache: foldersByQueryCache ?? this.foldersByQueryCache,
      folderDetailsCache: folderDetailsCache ?? this.folderDetailsCache,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      lastUploadedDocId: lastUploadedDocId ?? this.lastUploadedDocId,
      storageUsed: storageUsed ?? this.storageUsed,
      storageLimit: storageLimit ?? this.storageLimit,
      lastStorageSync: lastStorageSync ?? this.lastStorageSync,
      showingCachedData: showingCachedData ?? this.showingCachedData,
      pendingSyncJobs: pendingSyncJobs ?? this.pendingSyncJobs,
      failedSyncJobs: failedSyncJobs ?? this.failedSyncJobs,
      syncErrorsByDocumentId:
          syncErrorsByDocumentId ?? this.syncErrorsByDocumentId,
      syncJobTypesByDocumentId:
          syncJobTypesByDocumentId ?? this.syncJobTypesByDocumentId,
      syncHistory: syncHistory ?? this.syncHistory,
    );
  }

  /// Calculate storage dynamically from current documents list
  int calculateDynamicStorage() {
    return documents.fold<int>(0, (sum, doc) => sum + doc.sizeBytes.toInt());
  }
}

// --- Notifier ---
class DocumentNotifier extends StateNotifier<DocumentState> {
  final Ref _ref;
  final UploadDocument _uploadDocument;
  final GetDocuments _getDocuments;
  final DeleteDocument _deleteDocument;
  final DownloadDocument _downloadDocument;
  final PrepareDocumentForViewing _prepareDocumentForViewing;
  final DocumentSyncEngineService _syncEngine;
  bool _isLoadingDocuments = false;
  String? _activeDocumentsQueryKey;
  String? _lastLoadedDocumentsQueryKey;
  int _documentsRequestSeq = 0;
  final Map<String, List<DocumentEntity>> _documentsByQueryCache =
      <String, List<DocumentEntity>>{};
  final Map<String, DateTime> _documentsCacheAt = <String, DateTime>{};
  final Set<String> _loadingFolderKeys = <String>{};

  DocumentNotifier(
    this._ref, {
    required UploadDocument uploadDocument,
    required GetDocuments getDocuments,
    required DeleteDocument deleteDocument,
    required DownloadDocument downloadDocument,
    required PrepareDocumentForViewing prepareDocumentForViewing,
    required DocumentSyncEngineService syncEngine,
  })  : _uploadDocument = uploadDocument,
        _getDocuments = getDocuments,
        _deleteDocument = deleteDocument,
        _downloadDocument = downloadDocument,
        _prepareDocumentForViewing = prepareDocumentForViewing,
        _syncEngine = syncEngine,
        super(DocumentState.initial());

  bool _shouldQueueOffline(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('network error') ||
        message.contains('connection timeout') ||
        message.contains('socket') ||
        message.contains('timed out');
  }

  String _historyId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _loadSyncHistory(String familyId) async {
    final history = await _ref
        .read(syncHistoryLocalDataSourceProvider)
        .getEntries(familyId);
    state = state.copyWith(syncHistory: history);
  }

  Future<void> _recordSyncHistory({
    required String familyId,
    required String itemId,
    required String action,
    required String status,
    required String message,
    String itemType = 'document',
  }) async {
    final entry = SyncHistoryEntryModel(
      id: _historyId('sync-history'),
      familyId: familyId,
      itemType: itemType,
      itemId: itemId,
      action: action,
      status: status,
      message: message,
      createdAt: DateTime.now(),
    );
    await _ref.read(syncHistoryLocalDataSourceProvider).addEntry(entry);
    await _loadSyncHistory(familyId);
  }

  Future<void> _recordSyncProcessResult(
    String familyId,
    SyncProcessResult result,
  ) async {
    if (result.events.isEmpty) return;
    final historyDataSource = _ref.read(syncHistoryLocalDataSourceProvider);
    for (final event in result.events) {
      await historyDataSource.addEntry(
        SyncHistoryEntryModel(
          id: _historyId('sync-history'),
          familyId: familyId,
          itemType: event.itemType,
          itemId: event.itemId,
          action: event.action,
          status: event.status,
          message: event.message,
          createdAt: DateTime.now(),
        ),
      );
    }
    await _loadSyncHistory(familyId);
  }

  bool _matchesQuery(
    DocumentEntity document, {
    String? category,
    String? folder,
    String? memberId,
  }) {
    final requestedCategory = _canonicalCategory(category);
    if (requestedCategory != null &&
        _canonicalCategory(document.category) != requestedCategory) {
      return false;
    }
    if (folder != null && folder.isNotEmpty && document.folder != folder) {
      return false;
    }
    if ((memberId ?? '').isNotEmpty && document.memberId != memberId) {
      return false;
    }
    return true;
  }

  /// Load documents for family
  Future<void> loadDocuments({
    String? category,
    String? folder,
    String? memberId,
    bool forceRefresh = false,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) {
      if (kDebugMode) {
        debugPrint(
            'DocumentNotifier: User or familyId is null. User: ${user?.id}, FamilyId: ${user?.familyId}');
      }
      return;
    }

    await _loadSyncHistory(user.familyId!);

    final syncSnapshot = await _syncEngine.snapshotForFamily(user.familyId!);

    final queryKey =
        '${user.familyId}|${category ?? ''}|${folder ?? ''}|${memberId ?? ''}';

    final localCachedResult =
        await _ref.read(documentLocalDataSourceProvider).getCachedDocuments(
              familyId: user.familyId!,
              category: category,
              folder: folder,
              memberId: memberId,
            );

    if (localCachedResult != null) {
      final cachedDocs = (localCachedResult['documents'] as List<dynamic>)
          .whereType<DocumentEntity>()
          .toList();
      final visibleCachedDocs = cachedDocs
          .where((doc) => !syncSnapshot.pendingDeleteIds.contains(doc.id))
          .map((doc) {
        final movedFolder = syncSnapshot.pendingMoveFolders[doc.id];
        if (movedFolder != null) {
          return doc.copyWith(
            folder: movedFolder,
            syncStatus: syncSnapshot.failedDocumentIds.contains(doc.id)
                ? 'sync_failed'
                : 'pending_move',
          );
        }
        return doc;
      }).toList();
      final pendingUploads = syncSnapshot.pendingUploads
          .where((doc) => _matchesQuery(
                doc,
                category: category,
                folder: folder,
                memberId: memberId,
              ))
          .toList();
      final mergedCachedDocs = [...pendingUploads, ...visibleCachedDocs];
      _documentsByQueryCache[queryKey] = mergedCachedDocs;
      _documentsCacheAt[queryKey] = DateTime.now();
      state = state.copyWith(
        documents: mergedCachedDocs,
        storageUsed:
            localCachedResult['storageUsed'] as int? ?? state.storageUsed,
        storageLimit:
            localCachedResult['storageLimit'] as int? ?? state.storageLimit,
        lastStorageSync: DateTime.now(),
        isLoading: false,
        error: null,
        showingCachedData: true,
        pendingSyncJobs: syncSnapshot.pendingJobCount,
        failedSyncJobs: syncSnapshot.failedJobCount,
        syncErrorsByDocumentId: syncSnapshot.syncErrorsByDocumentId,
        syncJobTypesByDocumentId: syncSnapshot.syncJobTypesByDocumentId,
      );
      _lastLoadedDocumentsQueryKey = queryKey;
    }

    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      return;
    }

    // Check cache unless forceRefresh is true
    if (!forceRefresh) {
      if (_isLoadingDocuments && _activeDocumentsQueryKey == queryKey) {
        return;
      }
      final cachedDocs = _documentsByQueryCache[queryKey];
      final cachedAt = _documentsCacheAt[queryKey];
      if (cachedDocs != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt).inSeconds < 30) {
        // Increased to 30s
        final visibleCachedDocs = cachedDocs
            .where((doc) => !syncSnapshot.pendingDeleteIds.contains(doc.id))
            .map((doc) {
          final movedFolder = syncSnapshot.pendingMoveFolders[doc.id];
          if (movedFolder != null) {
            return doc.copyWith(
              folder: movedFolder,
              syncStatus: syncSnapshot.failedDocumentIds.contains(doc.id)
                  ? 'sync_failed'
                  : 'pending_move',
            );
          }
          return doc;
        }).toList();
        final pendingUploads = syncSnapshot.pendingUploads
            .where((doc) => _matchesQuery(
                  doc,
                  category: category,
                  folder: folder,
                  memberId: memberId,
                ))
            .toList();
        state = state.copyWith(
          documents: [...pendingUploads, ...visibleCachedDocs],
          isLoading: false,
          error: null,
          showingCachedData: false,
          pendingSyncJobs: syncSnapshot.pendingJobCount,
          failedSyncJobs: syncSnapshot.failedJobCount,
          syncErrorsByDocumentId: syncSnapshot.syncErrorsByDocumentId,
          syncJobTypesByDocumentId: syncSnapshot.syncJobTypesByDocumentId,
        );
        _lastLoadedDocumentsQueryKey = queryKey;
        return;
      }
    }

    final requestSeq = ++_documentsRequestSeq;
    final isQueryChanged = _lastLoadedDocumentsQueryKey != queryKey;

    if (kDebugMode) {
      debugPrint(
          'DocumentNotifier: Loading documents. FamilyId: ${user.familyId}, Query: $queryKey, Force: $forceRefresh');
    }
    _isLoadingDocuments = true;
    _activeDocumentsQueryKey = queryKey;

    // If query changed, try to use cached docs for the NEW query as initial placeholder
    final cachedForNewQuery = _documentsByQueryCache[queryKey];

    state = state.copyWith(
      isLoading: true,
      documents: isQueryChanged
          ? (cachedForNewQuery ?? const <DocumentEntity>[])
          : state.documents,
      error: null,
    );

    try {
      final syncResult = await _syncEngine.processPendingJobs(user.familyId!);
      await _recordSyncProcessResult(user.familyId!, syncResult);
      final result = await _getDocuments(
        user.familyId!,
        category: category,
        folder: folder,
        memberId: memberId,
      );

      if (requestSeq != _documentsRequestSeq) {
        return;
      }

      final requestedCanonical = _canonicalCategory(category);
      final fetchedDocs = List<DocumentEntity>.from(result['documents']);
      final fromCache = result['fromCache'] == true;

      // Secondary safety check for category filtering (if backend doesn't support it perfectly)
      final filteredDocs = requestedCanonical == null
          ? fetchedDocs
          : fetchedDocs
              .where((doc) =>
                  _canonicalCategory(doc.category) == requestedCanonical)
              .toList();
      final visibleDocs = filteredDocs
          .where((doc) => !syncSnapshot.pendingDeleteIds.contains(doc.id))
          .map((doc) {
        final movedFolder = syncSnapshot.pendingMoveFolders[doc.id];
        if (movedFolder != null) {
          return doc.copyWith(
            folder: movedFolder,
            syncStatus: syncSnapshot.failedDocumentIds.contains(doc.id)
                ? 'sync_failed'
                : 'pending_move',
          );
        }
        return doc;
      }).toList();
      final pendingUploads = syncSnapshot.pendingUploads
          .where((doc) => _matchesQuery(
                doc,
                category: category,
                folder: folder,
                memberId: memberId,
              ))
          .toList();
      final mergedDocs = [...pendingUploads, ...visibleDocs];

      _documentsByQueryCache[queryKey] = mergedDocs;
      _documentsCacheAt[queryKey] = DateTime.now();

      if (kDebugMode) {
        debugPrint(
            'DocumentNotifier: Loaded ${fetchedDocs.length} documents for $queryKey');
      }

      // Get storage from backend
      int finalStorageUsed = result['storageUsed'] ?? 0;
      final backendStorageLimit =
          result['storageLimit'] ?? (25 * 1024 * 1024 * 1024);

      state = state.copyWith(
        documents: mergedDocs,
        storageUsed: finalStorageUsed,
        storageLimit: backendStorageLimit,
        lastStorageSync: DateTime.now(),
        isLoading: false,
        showingCachedData: fromCache,
        pendingSyncJobs: syncSnapshot.pendingJobCount,
        failedSyncJobs: syncSnapshot.failedJobCount,
        syncErrorsByDocumentId: syncSnapshot.syncErrorsByDocumentId,
        syncJobTypesByDocumentId: syncSnapshot.syncJobTypesByDocumentId,
      );
      _lastLoadedDocumentsQueryKey = queryKey;
    } catch (e) {
      if (requestSeq != _documentsRequestSeq) {
        return;
      }
      if (kDebugMode) {
        debugPrint('DocumentNotifier: Error loading documents: $e');
      }
      final pendingUploads = syncSnapshot.pendingUploads
          .where((doc) => _matchesQuery(
                doc,
                category: category,
                folder: folder,
                memberId: memberId,
              ))
          .toList();
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        documents: pendingUploads.isNotEmpty ? pendingUploads : state.documents,
        pendingSyncJobs: syncSnapshot.pendingJobCount,
        failedSyncJobs: syncSnapshot.failedJobCount,
        syncErrorsByDocumentId: syncSnapshot.syncErrorsByDocumentId,
        syncJobTypesByDocumentId: syncSnapshot.syncJobTypesByDocumentId,
        showingCachedData: pendingUploads.isNotEmpty,
      );
    } finally {
      if (requestSeq == _documentsRequestSeq) {
        _isLoadingDocuments = false;
        _activeDocumentsQueryKey = null;
      }
    }
  }

  String? _canonicalCategory(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'individual' ||
        normalized == 'shared' ||
        normalized == 'family' ||
        normalized == 'family vault') return 'shared';
    if (normalized == 'personal') return 'personal';
    if (normalized == 'private' || normalized == 'private vault')
      return 'private';
    return normalized;
  }

  /// Upload a document
  Future<void> upload({
    required File file,
    required String title,
    required String category,
    String? folder,
    String? memberId,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) {
      if (kDebugMode) {
        debugPrint(
            'DocumentNotifier: Upload failed - User or familyId is null');
      }
      state = state.copyWith(error: "User not in a family");
      return;
    }

    if (kDebugMode) {
      debugPrint(
          'DocumentNotifier: Uploading document. FamilyId: ${user.familyId}, Category: $category, Title: $title');
    }
    state = state.copyWith(isLoading: true, error: null);
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      final queuedDoc = await _syncEngine.queueUpload(
        file: file,
        familyId: user.familyId!,
        title: title,
        category: category,
        uploadedBy: user.id,
        folder: folder,
        memberId: memberId,
      );
      final newStorageUsed = state.storageUsed + queuedDoc.sizeBytes.toInt();
        state = state.copyWith(
          documents: [queuedDoc, ...state.documents],
          storageUsed: newStorageUsed,
          lastStorageSync: DateTime.now(),
          isLoading: false,
          pendingSyncJobs: state.pendingSyncJobs + 1,
          error: null,
        );
        await _recordSyncHistory(
          familyId: user.familyId!,
          itemId: queuedDoc.id,
          action: 'upload',
          status: 'queued',
          message: 'Upload saved offline and queued for sync.',
        );
        for (final key in _documentsByQueryCache.keys.toList()) {
        final list = _documentsByQueryCache[key];
        if (list == null) continue;
        if (_matchesQuery(
          queuedDoc,
          category: key.split('|').length > 1 && key.split('|')[1].isNotEmpty
              ? key.split('|')[1]
              : null,
          folder: key.split('|').length > 2 && key.split('|')[2].isNotEmpty
              ? key.split('|')[2]
              : null,
          memberId: key.split('|').length > 3 && key.split('|')[3].isNotEmpty
              ? key.split('|')[3]
              : null,
        )) {
          _documentsByQueryCache[key] = [queuedDoc, ...list];
          _documentsCacheAt[key] = DateTime.now();
        }
      }
      return;
    }
    try {
      final newDoc = await _uploadDocument(
        file: file,
        familyId: user.familyId!,
        title: title,
        category: category,
        uploadedBy: user.id,
        folder: folder,
        memberId: memberId,
      );

      if (kDebugMode) {
        debugPrint(
            'DocumentNotifier: Upload successful. New Doc ID: ${newDoc.id}');
      }

      // Calculate new storage - add uploaded document size
      final newStorageUsed = state.storageUsed + (newDoc.sizeBytes).toInt();

      // Update current state locally
      state = state.copyWith(
        documents: [newDoc, ...state.documents],
        storageUsed: newStorageUsed,
        lastStorageSync: DateTime.now(),
        lastUploadedDocId: newDoc.id.isNotEmpty ? newDoc.id : null,
        isLoading: false,
      );

      // SURGICAL CACHE UPDATE:
      // 1. Update the "Global Recent" cache if it exists
      // Note: the key format used above was '${user.familyId}|${category ?? ''}|${folder ?? ''}|${memberId ?? ''}'
      // So global is '${user.familyId}|||'
      final actualGlobalKey = '${user.familyId}|||';

      final globalCached = _documentsByQueryCache[actualGlobalKey];
      if (globalCached != null) {
        // Prepend and limit to reasonable size (if needed, but usually okay)
        _documentsByQueryCache[actualGlobalKey] = [newDoc, ...globalCached];
        _documentsCacheAt[actualGlobalKey] = DateTime.now();
      }

      // 2. Update the cache for the query used during upload (if different from global)
      final uploadQueryKey =
          '${user.familyId}|${category}|${folder ?? ''}|${memberId ?? ''}';
      final uploadCached = _documentsByQueryCache[uploadQueryKey];
      if (uploadCached != null) {
        _documentsByQueryCache[uploadQueryKey] = [newDoc, ...uploadCached];
        _documentsCacheAt[uploadQueryKey] = DateTime.now();
      }

      // 3. Clear other specific caches to ensure they refresh on next hit,
      // but keep our primary ones above.
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DocumentNotifier: Upload error: $e');
      }
      if (_shouldQueueOffline(e)) {
        final queuedDoc = await _syncEngine.queueUpload(
          file: file,
          familyId: user.familyId!,
          title: title,
          category: category,
          uploadedBy: user.id,
          folder: folder,
          memberId: memberId,
        );
        final newStorageUsed = state.storageUsed + queuedDoc.sizeBytes.toInt();
          state = state.copyWith(
            documents: [queuedDoc, ...state.documents],
            storageUsed: newStorageUsed,
            lastStorageSync: DateTime.now(),
            isLoading: false,
            pendingSyncJobs: state.pendingSyncJobs + 1,
            failedSyncJobs: state.failedSyncJobs,
            error: null,
          );
          await _recordSyncHistory(
            familyId: user.familyId!,
            itemId: queuedDoc.id,
            action: 'upload',
            status: 'queued',
            message: 'Upload saved offline and queued for sync.',
          );
          for (final key in _documentsByQueryCache.keys.toList()) {
          final list = _documentsByQueryCache[key];
          if (list == null) continue;
          if (_matchesQuery(
            queuedDoc,
            category: key.split('|').length > 1 && key.split('|')[1].isNotEmpty
                ? key.split('|')[1]
                : null,
            folder: key.split('|').length > 2 && key.split('|')[2].isNotEmpty
                ? key.split('|')[2]
                : null,
            memberId: key.split('|').length > 3 && key.split('|')[3].isNotEmpty
                ? key.split('|')[3]
                : null,
          )) {
            _documentsByQueryCache[key] = [queuedDoc, ...list];
            _documentsCacheAt[key] = DateTime.now();
          }
        }
        return;
      }

      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Delete a document
  Future<void> delete(DocumentEntity document) async {
    if (document.id.startsWith('local-doc-')) {
      await _syncEngine.cancelPendingUpload(document.id);
      final newStorageUsed = (state.storageUsed - (document.sizeBytes).toInt())
          .clamp(0, double.maxFinite.toInt());
      state = state.copyWith(
        documents: state.documents.where((d) => d.id != document.id).toList(),
        storageUsed: newStorageUsed,
        pendingSyncJobs:
            state.pendingSyncJobs > 0 ? state.pendingSyncJobs - 1 : 0,
      );
      return;
    }

    // Optimistically remove from list
    final previousList = state.documents;
    final previousStorage = state.storageUsed;

    // Calculate new storage - subtract deleted document size
    final newStorageUsed = (state.storageUsed - (document.sizeBytes).toInt())
        .clamp(0, double.maxFinite.toInt());

    state = state.copyWith(
      documents: state.documents.where((d) => d.id != document.id).toList(),
      storageUsed: newStorageUsed,
      lastStorageSync: DateTime.now(),
    );

    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      final user = _ref.read(authProvider).user;
      if (user?.familyId != null) {
        await _syncEngine.queueDelete(
          familyId: user!.familyId!,
          documentId: document.id,
        );
        for (final key in _documentsByQueryCache.keys.toList()) {
          final list = _documentsByQueryCache[key];
          if (list != null) {
            _documentsByQueryCache[key] =
                list.where((d) => d.id != document.id).toList();
            _documentsCacheAt[key] = DateTime.now();
          }
        }
        state = state.copyWith(
          pendingSyncJobs: state.pendingSyncJobs + 1,
          failedSyncJobs: state.failedSyncJobs,
          error: null,
        );
        await _recordSyncHistory(
          familyId: user.familyId!,
          itemId: document.id,
          action: 'delete',
          status: 'queued',
          message: 'Delete queued and will sync when back online.',
        );
        return;
      }
    }

    try {
      await _deleteDocument(
        documentId: document.id,
      );

      // SURGICAL CACHE UPDATE for Delete:
      // Remove from all known cache entries to stay consistent
      for (final key in _documentsByQueryCache.keys.toList()) {
        final list = _documentsByQueryCache[key];
        if (list != null) {
          _documentsByQueryCache[key] =
              list.where((d) => d.id != document.id).toList();
        }
      }
    } catch (e) {
      if (_shouldQueueOffline(e)) {
        final user = _ref.read(authProvider).user;
        if (user?.familyId != null && !document.id.startsWith('local-doc-')) {
          await _syncEngine.queueDelete(
            familyId: user!.familyId!,
            documentId: document.id,
          );
          for (final key in _documentsByQueryCache.keys.toList()) {
            final list = _documentsByQueryCache[key];
            if (list != null) {
              _documentsByQueryCache[key] =
                  list.where((d) => d.id != document.id).toList();
              _documentsCacheAt[key] = DateTime.now();
            }
          }
            state = state.copyWith(
              pendingSyncJobs: state.pendingSyncJobs + 1,
              failedSyncJobs: state.failedSyncJobs,
              error: null,
            );
            await _recordSyncHistory(
              familyId: user.familyId!,
              itemId: document.id,
              action: 'delete',
              status: 'queued',
              message: 'Delete queued and will sync when back online.',
            );
            return;
          }
      }
      // Revert if failed
      state = state.copyWith(
          documents: previousList,
          storageUsed: previousStorage,
          error: "Failed to delete: $e");
    }
  }

  /// Download a document
  Future<String?> download(DocumentEntity document) async {
    try {
      final localPath = await _downloadDocument(document);
      final updatedDocs = state.documents.map((doc) {
        if (doc.id != document.id) return doc;
        return doc.copyWith(
          localPath: localPath,
          isOfflineAvailable: true,
        );
      }).toList();
      state = state.copyWith(documents: updatedDocs);
      return localPath;
    } catch (e) {
      state = state.copyWith(error: "Failed to download: $e");
      return null;
    }
  }

  Future<String?> prepareForViewing(DocumentEntity document) async {
    try {
      return await _prepareDocumentForViewing(document);
    } catch (e) {
      state = state.copyWith(error: "Failed to open document: $e");
      return null;
    }
  }

  Future<void> removeOfflineCopy(DocumentEntity document) async {
    try {
      final repository = _ref.read(documentRepositoryProvider);
      await repository.removeOfflineCopy(document);
      final updatedDocs = state.documents.map((doc) {
        if (doc.id != document.id) return doc;
        return doc.copyWith(
          localPath: null,
          isOfflineAvailable: false,
        );
      }).toList();
      state = state.copyWith(documents: updatedDocs);
    } catch (e) {
      state = state.copyWith(error: "Failed to remove offline copy: $e");
      rethrow;
    }
  }

  Future<void> syncPendingJobs({bool reloadDocuments = true}) async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;

    final syncResult = await _syncEngine.processPendingJobs(user!.familyId!);
    await _recordSyncProcessResult(user.familyId!, syncResult);
    final snapshot = await _syncEngine.snapshotForFamily(user.familyId!);
    state = state.copyWith(
      pendingSyncJobs: snapshot.pendingJobCount,
      failedSyncJobs: snapshot.failedJobCount,
      syncErrorsByDocumentId: snapshot.syncErrorsByDocumentId,
      syncJobTypesByDocumentId: snapshot.syncJobTypesByDocumentId,
    );

    if (reloadDocuments) {
      await loadDocuments(forceRefresh: true);
    }
  }

  Future<void> retryFailedSyncJobs() async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _syncEngine.retryFailedJobs(user!.familyId!);
      await _recordSyncHistory(
        familyId: user.familyId!,
        itemId: 'all',
        action: 'retry',
        status: 'requested',
        message: 'Retry requested for failed sync jobs.',
      );
      await loadDocuments(forceRefresh: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to retry sync jobs: $e',
      );
      rethrow;
    }
  }

  Future<void> clearFailedSyncJobs() async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _syncEngine.clearFailedJobs(user!.familyId!);
      await _recordSyncHistory(
        familyId: user.familyId!,
        itemId: 'all',
        action: 'clear_failed',
        status: 'success',
        message: 'Failed sync jobs cleared on this device.',
      );
      await loadDocuments(forceRefresh: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to clear sync jobs: $e',
      );
      rethrow;
    }
  }

  /// Recalculate storage from current documents (useful for sync verification)
  void recalculateStorage() {
    if (state.documents.isEmpty) {
      if (kDebugMode) {
        debugPrint('DocumentNotifier: No documents to calculate storage from');
      }
      return;
    }

    final calculatedStorage =
        state.documents.fold<int>(0, (sum, doc) => sum + doc.sizeBytes.toInt());

    if (calculatedStorage != state.storageUsed) {
      if (kDebugMode) {
        debugPrint(
            'DocumentNotifier: Storage recalculated - Old: ${state.storageUsed}, New: $calculatedStorage');
      }
      state = state.copyWith(
        storageUsed: calculatedStorage,
        lastStorageSync: DateTime.now(),
      );
    }
  }

  /// Force refresh storage from backend
  Future<void> refreshStorage() async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return;

    try {
      // Reload documents to get fresh storage info
      await loadDocuments();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DocumentNotifier: Failed to refresh storage: $e');
      }
    }
  }

  Future<void> loadFolders({required String category, String? memberId}) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return;
    final folderKey = '${user.familyId}|$category|${memberId ?? ''}';
    if (_loadingFolderKeys.contains(folderKey)) return;
    _loadingFolderKeys.add(folderKey);
    try {
      final repository = _ref.read(documentRepositoryProvider);
      final folders = await repository.getFolders(
        familyId: user.familyId!,
        category: category,
        memberId: memberId,
      );
      // Also load folder details
      final folderDetails = await repository.getFolderDetails(
        familyId: user.familyId!,
        category: category,
        memberId: memberId,
      );
      final newCache =
          Map<String, List<FolderEntity>>.from(state.folderDetailsCache);
      newCache[folderKey] = folderDetails;
      final foldersCache =
          Map<String, List<String>>.from(state.foldersByQueryCache);
      foldersCache[folderKey] = folders;
      if (!listEquals(state.foldersByQueryCache[folderKey], folders) ||
          state.error != null) {
        state = state.copyWith(
          folders: folders,
          foldersByQueryCache: foldersCache,
          folderDetailsCache: newCache,
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to load folders: $e');
    } finally {
      _loadingFolderKeys.remove(folderKey);
    }
  }

  List<FolderEntity>? getFolderDetails(
      {required String category, String? memberId}) {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return null;
    final folderKey = '${user.familyId}|$category|${memberId ?? ''}';
    return state.folderDetailsCache[folderKey];
  }

  List<String> getFoldersForQuery({
    required String category,
    String? memberId,
  }) {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return state.folders;
    final folderKey = '${user.familyId}|$category|${memberId ?? ''}';
    return state.foldersByQueryCache[folderKey] ?? state.folders;
  }

  Future<void> createFolder({
    required String category,
    required String name,
    String? memberId,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return;
    try {
      final repository = _ref.read(documentRepositoryProvider);
      await repository.createFolder(
        familyId: user.familyId!,
        category: category,
        name: name,
        memberId: memberId,
      );
      await loadFolders(category: category, memberId: memberId);
    } catch (e) {
      state = state.copyWith(error: 'Failed to create folder: $e');
      rethrow;
    }
  }

  Future<void> renameFolder({
    required String folderId,
    required String newName,
    required String category,
    String? memberId,
  }) async {
    try {
      final repository = _ref.read(documentRepositoryProvider);
      await repository.renameFolder(
        folderId: folderId,
        newName: newName,
      );
      await loadFolders(category: category, memberId: memberId);
      await loadDocuments(
        category: category,
        memberId: memberId,
        forceRefresh: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename folder: $e');
      rethrow;
    }
  }

  Future<void> deleteFolder({
    required String folderId,
    required String category,
    String? folderName,
    String? familyId,
    String? memberId,
  }) async {
    try {
      final repository = _ref.read(documentRepositoryProvider);
      await repository.deleteFolder(
        folderId: folderId,
        folderName: folderName,
        familyId: familyId,
        category: category,
        memberId: memberId,
      );
      await loadFolders(category: category, memberId: memberId);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete folder: $e');
      rethrow;
    }
  }

  Future<void> moveDocumentToFolder({
    required DocumentEntity document,
    required String folder,
    String? memberId,
  }) async {
    final previousDocs = state.documents;
    final optimisticDocument = document.copyWith(
      folder: folder,
      syncStatus: document.id.startsWith('local-doc-')
          ? 'pending_upload'
          : 'pending_move',
    );
    state = state.copyWith(
      documents: state.documents
          .map((d) => d.id == document.id ? optimisticDocument : d)
          .toList(),
      error: null,
    );
    for (final key in _documentsByQueryCache.keys.toList()) {
      final list = _documentsByQueryCache[key];
      if (list == null) continue;
      _documentsByQueryCache[key] = list
          .map((d) => d.id == document.id ? optimisticDocument : d)
          .toList();
      _documentsCacheAt[key] = DateTime.now();
    }

    try {
      if (document.id.startsWith('local-doc-')) {
        final updatedPendingUpload =
            await _syncEngine.updatePendingUploadFolder(
          localDocumentId: document.id,
          folder: folder,
          memberId: memberId,
        );
        if (!updatedPendingUpload) {
          throw Exception(
              'Pending upload job was not found for this document.');
        }
        return;
      }

      final isOnline = _ref.read(isOnlineProvider);
      if (!isOnline) {
        final user = _ref.read(authProvider).user;
        if (user?.familyId != null) {
          await _syncEngine.queueMove(
            familyId: user!.familyId!,
            document: document,
            folder: folder,
            memberId: memberId,
          );
          final snapshot = await _syncEngine.snapshotForFamily(user.familyId!);
            state = state.copyWith(
              pendingSyncJobs: snapshot.pendingJobCount,
              failedSyncJobs: snapshot.failedJobCount,
              error: null,
            );
            await _recordSyncHistory(
              familyId: user.familyId!,
              itemId: document.id,
              action: 'move',
              status: 'queued',
              message: 'Folder move queued and will sync when back online.',
            );
            return;
          }
      }

      final repository = _ref.read(documentRepositoryProvider);
      final updated = await repository.moveDocumentToFolder(
        documentId: document.id,
        folder: folder,
        memberId: memberId,
      );
      final newDocs = state.documents
          .map((d) => d.id == document.id ? updated : d)
          .toList();
      state = state.copyWith(documents: newDocs);

      for (final key in _documentsByQueryCache.keys.toList()) {
        final list = _documentsByQueryCache[key];
        if (list != null) {
          _documentsByQueryCache[key] =
              list.map((d) => d.id == document.id ? updated : d).toList();
          _documentsCacheAt[key] = DateTime.now();
        }
      }
    } catch (e) {
      if (!document.id.startsWith('local-doc-') && _shouldQueueOffline(e)) {
        final user = _ref.read(authProvider).user;
        if (user?.familyId != null) {
          await _syncEngine.queueMove(
            familyId: user!.familyId!,
            document: document,
            folder: folder,
            memberId: memberId,
          );
          final snapshot = await _syncEngine.snapshotForFamily(user.familyId!);
            state = state.copyWith(
              pendingSyncJobs: snapshot.pendingJobCount,
              failedSyncJobs: snapshot.failedJobCount,
              error: null,
            );
            await _recordSyncHistory(
              familyId: user.familyId!,
              itemId: document.id,
              action: 'move',
              status: 'queued',
              message: 'Folder move queued and will sync when back online.',
            );
            return;
          }
      }

      state = state.copyWith(
        documents: previousDocs,
        error: 'Failed to move document: $e',
      );
      for (final key in _documentsByQueryCache.keys.toList()) {
        final list = _documentsByQueryCache[key];
        if (list == null) continue;
        _documentsByQueryCache[key] =
            list.map((d) => d.id == document.id ? document : d).toList();
        _documentsCacheAt[key] = DateTime.now();
      }
      rethrow;
    }
  }

  String? syncErrorForDocument(String documentId) {
    return state.syncErrorsByDocumentId[documentId];
  }

  String? syncJobTypeForDocument(String documentId) {
    return state.syncJobTypesByDocumentId[documentId];
  }

  Future<void> retryFailedSyncForDocument(String documentId) async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _syncEngine.retryFailedJobForDocument(
        familyId: user!.familyId!,
        documentId: documentId,
      );
      await _recordSyncHistory(
        familyId: user.familyId!,
        itemId: documentId,
        action: 'retry',
        status: 'requested',
        message: 'Retry requested for this document.',
      );
      await loadDocuments(forceRefresh: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to retry document sync: $e',
      );
      rethrow;
    }
  }

  Future<void> clearFailedSyncForDocument(String documentId) async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _syncEngine.clearFailedJobForDocument(
        familyId: user!.familyId!,
        documentId: documentId,
      );
      await _recordSyncHistory(
        familyId: user.familyId!,
        itemId: documentId,
        action: 'clear_failed',
        status: 'success',
        message: 'Failed sync removed for this document.',
      );
      await loadDocuments(forceRefresh: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to clear document sync: $e',
      );
      rethrow;
    }
  }

  bool hasConflictForDocument(String documentId) {
    final error = syncErrorForDocument(documentId)?.toLowerCase() ?? '';
    return error.contains('conflict') ||
        error.contains('no longer exists') ||
        error.contains('no longer be applied');
  }

  Future<void> resolveFailedSyncConflict(String documentId) async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;
    final familyId = user!.familyId!;

    final syncType = syncJobTypeForDocument(documentId);
    final syncError = syncErrorForDocument(documentId)?.toLowerCase() ?? '';
    final document = state.documents.firstWhere(
      (item) => item.id == documentId,
      orElse: () => DocumentEntity(
        id: documentId,
        familyId: familyId,
        title: '',
        category: 'Shared',
        fileUrl: '',
        fileType: 'application/octet-stream',
        sizeBytes: 0,
        uploadedBy: user.id,
        uploadedAt: DateTime.now(),
        storagePath: '',
      ),
    );

    if (syncType == 'move' && syncError.contains('folder no longer exists')) {
      await _syncEngine.queueMove(
        familyId: familyId,
        document: document,
        folder: 'General',
      );
      await _recordSyncHistory(
        familyId: familyId,
        itemId: documentId,
        action: 'resolve_conflict',
        status: 'requested',
        message: 'Conflict resolution applied: move target changed to General.',
      );
      await retryFailedSyncForDocument(documentId);
      return;
    }

    await clearFailedSyncForDocument(documentId);
    await _recordSyncHistory(
      familyId: familyId,
      itemId: documentId,
      action: 'resolve_conflict',
      status: 'success',
      message: 'Conflict cleared on this device.',
    );
  }

  Future<List<DocumentEntity>> getOfflineLibrary() async {
    return _ref.read(documentLocalDataSourceProvider).getAllOfflineDocuments();
  }
}

// --- Provider ---
final documentProvider =
    StateNotifierProvider<DocumentNotifier, DocumentState>((ref) {
  return DocumentNotifier(
    ref,
    uploadDocument: ref.read(uploadDocumentUseCaseProvider),
    getDocuments: ref.read(getDocumentsUseCaseProvider),
    deleteDocument: ref.read(deleteDocumentUseCaseProvider),
    downloadDocument: ref.read(downloadDocumentUseCaseProvider),
    prepareDocumentForViewing:
        ref.read(prepareDocumentForViewingUseCaseProvider),
    syncEngine: ref.read(documentSyncEngineServiceProvider),
  );
});
