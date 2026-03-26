import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/repositories/document_repository.dart';

class PrepareDocumentForViewing {
  final DocumentRepository repository;

  PrepareDocumentForViewing(this.repository);

  Future<String> call(DocumentEntity document) async {
    return repository.prepareDocumentForViewing(document);
  }
}
