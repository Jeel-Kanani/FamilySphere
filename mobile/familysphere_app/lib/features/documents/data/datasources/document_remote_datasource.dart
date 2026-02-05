import 'dart:io';
import 'package:dio/dio.dart';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/features/documents/data/models/document_model.dart';

class DocumentRemoteDataSource {
  final ApiClient _apiClient;

  DocumentRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Upload document
  Future<DocumentModel> uploadDocument({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      'category': category,
      'familyId': familyId,
      'uploadedBy': uploadedBy,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    final response = await _apiClient.post(
      '/api/documents/upload',
      data: formData,
    );

    return DocumentModel.fromJson(response.data);
  }

  /// Get documents
  Future<Map<String, dynamic>> getDocuments(String familyId, {String? category}) async {
    final response = await _apiClient.get(
      '/api/documents/family/$familyId',
      queryParameters: category != null ? {'category': category} : null,
    );
    
    final List<dynamic> docsJson = response.data['documents'];
    final documents = docsJson.map((json) => DocumentModel.fromJson(json)).toList();
    
    return {
      'documents': documents,
      'storageUsed': response.data['storageUsed'],
      'storageLimit': response.data['storageLimit'],
    };
  }

  /// Delete document
  Future<void> deleteDocument({
    required String documentId,
  }) async {
    await _apiClient.delete('/api/documents/$documentId');
  }
}
