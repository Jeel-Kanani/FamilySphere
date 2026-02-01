import 'dart:io';

import 'package:familysphere_app/features/documents/data/models/document_model.dart';

class DocumentRemoteDataSource {
  DocumentRemoteDataSource();

  /// Upload document (Stubbed)
  Future<DocumentModel> uploadDocument({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
  }) async {
    // TODO: Implement custom backend upload
    throw UnimplementedError('Document upload is not yet implemented for custom backend.');
  }

  /// Get documents (Stubbed)
  Future<List<DocumentModel>> getDocuments(String familyId, {String? category}) async {
    // TODO: Implement custom backend retrieval
    return [];
  }

  /// Delete document (Stubbed)
  Future<void> deleteDocument({
    required String documentId,
    required String familyId,
    required String storagePath,
  }) async {
    // TODO: Implement custom backend delete
  }
}
