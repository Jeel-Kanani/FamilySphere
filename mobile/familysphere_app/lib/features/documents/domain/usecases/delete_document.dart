import 'package:familysphere_app/features/documents/domain/repositories/document_repository.dart';

class DeleteDocument {
  final DocumentRepository repository;

  DeleteDocument(this.repository);

  Future<void> call({
    required String documentId,
    required String familyId,
    required String storagePath,
  }) async {
    return await repository.deleteDocument(
      documentId: documentId,
      familyId: familyId,
      storagePath: storagePath,
    );
  }
}
