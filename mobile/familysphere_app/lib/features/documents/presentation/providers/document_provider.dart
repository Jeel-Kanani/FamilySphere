import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/entities/folder_entity.dart';
import 'package:familysphere_app/features/documents/domain/usecases/upload_document.dart';
import 'package:familysphere_app/features/documents/domain/usecases/get_documents.dart';
import 'package:familysphere_app/features/documents/domain/usecases/delete_document.dart';
import 'package:familysphere_app/features/documents/domain/usecases/download_document.dart';
import 'package:familysphere_app/features/documents/data/repositories/document_repository_impl.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

// --- Data Source Provider ---
final documentRemoteDataSourceProvider = Provider((ref) {
  return DocumentRemoteDataSource(apiClient: ref.read(apiClientProvider));
});

// --- Repository Provider ---
final documentRepositoryProvider = Provider((ref) {
  return DocumentRepositoryImpl(
    remoteDataSource: ref.read(documentRemoteDataSourceProvider),
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

// --- State ---
class DocumentState {
  final List<DocumentEntity> documents;
  final List<String> folders;
  final Map<String, List<FolderEntity>> folderDetailsCache;
  final bool isLoading;
  final String? error;
  final double? uploadProgress; 
  final int storageUsed;
  final int storageLimit;

  const DocumentState({
    this.documents = const [],
    this.folders = const [],
    this.folderDetailsCache = const {},
    this.isLoading = false,
    this.error,
    this.uploadProgress,
    this.storageUsed = 0,
    this.storageLimit = 25 * 1024 * 1024 * 1024, // 25 GB default
  });

  factory DocumentState.initial() => const DocumentState();

  DocumentState copyWith({
    List<DocumentEntity>? documents,
    List<String>? folders,
    Map<String, List<FolderEntity>>? folderDetailsCache,
    bool? isLoading,
    String? error,
    double? uploadProgress,
    int? storageUsed,
    int? storageLimit,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      folders: folders ?? this.folders,
      folderDetailsCache: folderDetailsCache ?? this.folderDetailsCache,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      storageUsed: storageUsed ?? this.storageUsed,
      storageLimit: storageLimit ?? this.storageLimit,
    );
  }
}

// --- Notifier ---
class DocumentNotifier extends StateNotifier<DocumentState> {
  final Ref _ref;
  final UploadDocument _uploadDocument;
  final GetDocuments _getDocuments;
  final DeleteDocument _deleteDocument;
  final DownloadDocument _downloadDocument;
  bool _isLoadingDocuments = false;
  String? _activeDocumentsQueryKey;
  String? _lastLoadedDocumentsQueryKey;
  int _documentsRequestSeq = 0;
  final Map<String, List<DocumentEntity>> _documentsByQueryCache = <String, List<DocumentEntity>>{};
  final Map<String, DateTime> _documentsCacheAt = <String, DateTime>{};
  final Set<String> _loadingFolderKeys = <String>{};

  DocumentNotifier(
    this._ref, {
    required UploadDocument uploadDocument,
    required GetDocuments getDocuments,
    required DeleteDocument deleteDocument,
    required DownloadDocument downloadDocument,
  })  : _uploadDocument = uploadDocument,
        _getDocuments = getDocuments,
        _deleteDocument = deleteDocument,
        _downloadDocument = downloadDocument,
        super(DocumentState.initial());

  /// Load documents for family
  Future<void> loadDocuments({String? category, String? folder, String? memberId}) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) {
      if (kDebugMode) {
        debugPrint('DocumentNotifier: User or familyId is null. User: ${user?.id}, FamilyId: ${user?.familyId}');
      }
      return;
    }

    final queryKey = '${user.familyId}|${category ?? ''}|${folder ?? ''}|${memberId ?? ''}';
    if (_isLoadingDocuments && _activeDocumentsQueryKey == queryKey) {
      return;
    }
    final cachedDocs = _documentsByQueryCache[queryKey];
    final cachedAt = _documentsCacheAt[queryKey];
    if (cachedDocs != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt).inSeconds < 20) {
      state = state.copyWith(
        documents: cachedDocs,
        isLoading: false,
        error: null,
      );
      _lastLoadedDocumentsQueryKey = queryKey;
      return;
    }
    final requestSeq = ++_documentsRequestSeq;
    final isQueryChanged = _lastLoadedDocumentsQueryKey != queryKey;

    if (kDebugMode) {
      debugPrint('DocumentNotifier: Loading documents. FamilyId: ${user.familyId}, Category: $category, Folder: $folder, MemberId: $memberId');
    }
    _isLoadingDocuments = true;
    _activeDocumentsQueryKey = queryKey;
    state = state.copyWith(
      isLoading: true,
      documents: isQueryChanged ? const <DocumentEntity>[] : state.documents,
      error: null,
    );
    try {
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
      final filteredDocs = requestedCanonical == null
          ? fetchedDocs
          : fetchedDocs.where((doc) => _canonicalCategory(doc.category) == requestedCanonical).toList();
      _documentsByQueryCache[queryKey] = filteredDocs;
      _documentsCacheAt[queryKey] = DateTime.now();
      if (kDebugMode) {
        debugPrint('DocumentNotifier: Loaded ${fetchedDocs.length} documents, kept ${filteredDocs.length} after category guard');
      }
      state = state.copyWith(
        documents: filteredDocs,
        storageUsed: result['storageUsed'],
        storageLimit: result['storageLimit'],
        isLoading: false,
      );
      _lastLoadedDocumentsQueryKey = queryKey;
    } catch (e) {
      if (requestSeq != _documentsRequestSeq) {
        return;
      }
      if (kDebugMode) {
        debugPrint('DocumentNotifier: Error loading documents: $e');
      }
      state = state.copyWith(isLoading: false, error: e.toString());
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
    if (normalized == 'individual' || normalized == 'shared' || normalized == 'family' || normalized == 'family vault') return 'shared';
    if (normalized == 'personal') return 'personal';
    if (normalized == 'private' || normalized == 'private vault') return 'private';
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
        debugPrint('DocumentNotifier: Upload failed - User or familyId is null');
      }
      state = state.copyWith(error: "User not in a family");
      return;
    }

    if (kDebugMode) {
      debugPrint('DocumentNotifier: Uploading document. FamilyId: ${user.familyId}, Category: $category, Title: $title');
    }
    state = state.copyWith(isLoading: true, error: null);
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
        debugPrint('DocumentNotifier: Upload successful. New Doc ID: ${newDoc.id}');
      }
      // Update list locally
      state = state.copyWith(
        documents: [newDoc, ...state.documents],
        storageUsed: state.storageUsed + (newDoc.sizeBytes).toInt(),
        isLoading: false,
      );
      _documentsByQueryCache.clear();
      _documentsCacheAt.clear();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DocumentNotifier: Upload error: $e');
      }
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Delete a document
  Future<void> delete(DocumentEntity document) async {
    // Optimistically remove from list
    final previousList = state.documents;
    final previousStorage = state.storageUsed;

    state = state.copyWith(
      documents: state.documents.where((d) => d.id != document.id).toList(),
      storageUsed: state.storageUsed - (document.sizeBytes).toInt(),
    );

    try {
      await _deleteDocument(
        documentId: document.id,
      );
      _documentsByQueryCache.clear();
      _documentsCacheAt.clear();
    } catch (e) {
      // Revert if failed
      state = state.copyWith(
        documents: previousList, 
        storageUsed: previousStorage,
        error: "Failed to delete: $e"
      );
    }
  }

  /// Download a document
  Future<String?> download(DocumentEntity document) async {
    try {
      return await _downloadDocument(document);
    } catch (e) {
      state = state.copyWith(error: "Failed to download: $e");
      return null;
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
      final newCache = Map<String, List<FolderEntity>>.from(state.folderDetailsCache);
      newCache[folderKey] = folderDetails;
      if (!listEquals(state.folders, folders) || state.error != null) {
        state = state.copyWith(folders: folders, folderDetailsCache: newCache, error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to load folders: $e');
    } finally {
      _loadingFolderKeys.remove(folderKey);
    }
  }

  List<FolderEntity>? getFolderDetails({required String category, String? memberId}) {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return null;
    final folderKey = '${user.familyId}|$category|${memberId ?? ''}';
    return state.folderDetailsCache[folderKey];
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
    try {
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
      _documentsByQueryCache.clear();
      _documentsCacheAt.clear();
    } catch (e) {
      state = state.copyWith(error: 'Failed to move document: $e');
      rethrow;
    }
  }
}

// --- Provider ---
final documentProvider = StateNotifierProvider<DocumentNotifier, DocumentState>((ref) {
  return DocumentNotifier(
    ref,
    uploadDocument: ref.read(uploadDocumentUseCaseProvider),
    getDocuments: ref.read(getDocumentsUseCaseProvider),
    deleteDocument: ref.read(deleteDocumentUseCaseProvider),
    downloadDocument: ref.read(downloadDocumentUseCaseProvider),
  );
});
