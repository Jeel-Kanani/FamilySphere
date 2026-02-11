import 'dart:io';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/domain/repositories/document_repository.dart';
import 'package:familysphere_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentRemoteDataSource remoteDataSource;

  DocumentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<DocumentEntity> uploadDocument({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
    String? folder,
    String? memberId,
  }) async {
    return await remoteDataSource.uploadDocument(
      file: file,
      familyId: familyId,
      title: title,
      category: category,
      uploadedBy: uploadedBy,
      folder: folder,
      memberId: memberId,
    );
  }

  @override
  Future<Map<String, dynamic>> getDocuments(String familyId, {String? category, String? folder, String? memberId}) async {
    return await remoteDataSource.getDocuments(
      familyId,
      category: category,
      folder: folder,
      memberId: memberId,
    );
  }

  @override
  Future<void> deleteDocument({
    required String documentId,
  }) async {
    await remoteDataSource.deleteDocument(
      documentId: documentId,
    );
  }

  @override
  Future<List<String>> getFolders({
    required String familyId,
    required String category,
    String? memberId,
  }) async {
    return await remoteDataSource.getFolders(
      familyId: familyId,
      category: category,
      memberId: memberId,
    );
  }

  @override
  Future<void> createFolder({
    required String familyId,
    required String category,
    required String name,
    String? memberId,
  }) async {
    await remoteDataSource.createFolder(
      familyId: familyId,
      category: category,
      name: name,
      memberId: memberId,
    );
  }

  @override
  Future<DocumentEntity> moveDocumentToFolder({
    required String documentId,
    required String folder,
    String? memberId,
  }) async {
    return await remoteDataSource.moveDocumentToFolder(
      documentId: documentId,
      folder: folder,
      memberId: memberId,
    );
  }

  @override
  Future<String> downloadDocument(DocumentEntity document) async {
    try {
      final response = await http.get(Uri.parse(document.fileUrl));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final filename = '${document.id}_${document.title.replaceAll(RegExp(r'[^\w\s\.]'), '_')}';
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }
}
