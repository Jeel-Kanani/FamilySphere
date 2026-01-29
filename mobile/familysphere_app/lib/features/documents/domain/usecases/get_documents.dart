import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/repositories/document_repository.dart';

class GetDocuments {
  final DocumentRepository repository;

  GetDocuments(this.repository);

  Future<List<DocumentEntity>> call(String familyId, {String? category}) async {
    return await repository.getDocuments(familyId, category: category);
  }
}
