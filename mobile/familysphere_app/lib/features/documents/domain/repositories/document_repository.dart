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
    String? folder,
    String? memberId,
  });

  /// Get list of documents and storage info for a family
  /// 
  /// [familyId] - ID of the family
  /// [category] - Optional filter by category
  Future<Map<String, dynamic>> getDocuments(String familyId, {String? category, String? folder, String? memberId});

  /// Delete a document
  /// 
  /// [documentId] - ID of document to delete
  Future<void> deleteDocument({
    required String documentId,
  });

  /// Get folders for a vault category
  Future<List<String>> getFolders({
    required String familyId,
    required String category,
    String? memberId,
  });

  /// Create a custom folder inside a vault category
  Future<void> createFolder({
    required String familyId,
    required String category,
    required String name,
    String? memberId,
  });

  /// Move a document into a folder
  Future<DocumentEntity> moveDocumentToFolder({
    required String documentId,
    required String folder,
    String? memberId,
  });

  /// Download a document for offline access
  /// 
  /// [document] - The document to download
  /// 
  /// Returns path to local file
  Future<String> downloadDocument(DocumentEntity document);
}
