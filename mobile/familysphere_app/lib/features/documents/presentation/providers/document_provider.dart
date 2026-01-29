import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/usecases/upload_document.dart';
import 'package:familysphere_app/features/documents/domain/usecases/get_documents.dart';
import 'package:familysphere_app/features/documents/domain/usecases/delete_document.dart';
import 'package:familysphere_app/features/documents/domain/usecases/download_document.dart';
import 'package:familysphere_app/features/documents/data/repositories/document_repository_impl.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

// --- Data Source Provider ---
final documentRemoteDataSourceProvider = Provider((ref) {
  return DocumentRemoteDataSource();
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
  final bool isLoading;
  final String? error;
  final double? uploadProgress; // Null if not uploading

  const DocumentState({
    this.documents = const [],
    this.isLoading = false,
    this.error,
    this.uploadProgress,
  });

  factory DocumentState.initial() => const DocumentState();

  DocumentState copyWith({
    List<DocumentEntity>? documents,
    bool? isLoading,
    String? error,
    double? uploadProgress,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      error: error, // If passed, update. If null, keep null unless intentional clearing logic is used elsewhere.
      uploadProgress: uploadProgress ?? this.uploadProgress,
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
  Future<void> loadDocuments({String? category}) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final docs = await _getDocuments(user.familyId!, category: category);
      state = state.copyWith(
        documents: docs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Upload a document
  Future<void> upload({
    required File file,
    required String title,
    required String category,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) {
      state = state.copyWith(error: "User not in a family");
      return;
    }

    state = state.copyWith(isLoading: true, error: null); // Could imply upload progress here
    try {
      final newDoc = await _uploadDocument(
        file: file,
        familyId: user.familyId!,
        title: title,
        category: category,
        uploadedBy: user.id,
      );
      
      // Update list locally
      state = state.copyWith(
        documents: [newDoc, ...state.documents],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Delete a document
  Future<void> delete(DocumentEntity document) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.familyId == null) return;

    // Optimistically remove from list
    final previousList = state.documents;
    state = state.copyWith(
      documents: state.documents.where((d) => d.id != document.id).toList(),
    );

    try {
      await _deleteDocument(
        documentId: document.id,
        familyId: user.familyId!,
        storagePath: document.storagePath,
      );
    } catch (e) {
      // Revert if failed
      state = state.copyWith(documents: previousList, error: "Failed to delete: $e");
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
