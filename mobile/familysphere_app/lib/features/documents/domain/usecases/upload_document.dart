import 'dart:io';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/repositories/document_repository.dart';

class UploadDocument {
  final DocumentRepository repository;

  UploadDocument(this.repository);

  Future<DocumentEntity> call({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
  }) async {
    return await repository.uploadDocument(
      file: file,
      familyId: familyId,
      title: title,
      category: category,
      uploadedBy: uploadedBy,
    );
  }
}
