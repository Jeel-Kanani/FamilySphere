import 'dart:io';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';

/// Document Repository Interface
/// 
/// Defines operations for managing family documents.
abstract class DocumentRepository {
  /// Upload a new document
  /// 
  /// [file] - The local file to upload
  /// [familyId] - ID of the family owning the document
  /// [title] - User-friendly title
  /// [category] - Category tag (e.g., 'Insurance', 'Medical')
  /// [uploadedBy] - ID of user uploading
  /// 
  /// Returns the created DocumentEntity
  Future<DocumentEntity> uploadDocument({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
  });

  /// Get list of documents and storage info for a family
  /// 
  /// [familyId] - ID of the family
  /// [category] - Optional filter by category
  Future<Map<String, dynamic>> getDocuments(String familyId, {String? category});

  /// Delete a document
  /// 
  /// [documentId] - ID of document to delete
  Future<void> deleteDocument({
    required String documentId,
  });

  /// Download a document for offline access
  /// 
  /// [document] - The document to download
  /// 
  /// Returns path to local file
  Future<String> downloadDocument(DocumentEntity document);
}
