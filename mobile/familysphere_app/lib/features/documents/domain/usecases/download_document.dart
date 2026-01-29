import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/repositories/document_repository.dart';

class DownloadDocument {
  final DocumentRepository repository;

  DownloadDocument(this.repository);

  Future<String> call(DocumentEntity document) async {
    return await repository.downloadDocument(document);
  }
}
