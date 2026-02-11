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
    String? folder,
    String? memberId,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      'category': category,
      'folder': folder ?? 'General',
      'familyId': familyId,
      'uploadedBy': uploadedBy,
      if (memberId != null) 'memberId': memberId,
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
  Future<Map<String, dynamic>> getDocuments(String familyId, {String? category, String? folder, String? memberId}) async {
    final query = <String, dynamic>{};
    if (category != null) query['category'] = category;
    if (folder != null) query['folder'] = folder;
    if (memberId != null) query['memberId'] = memberId;
    final response = await _apiClient.get(
      '/api/documents/family/$familyId',
      queryParameters: query.isEmpty ? null : query,
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

  Future<List<String>> getFolders({
    required String familyId,
    required String category,
    String? memberId,
  }) async {
    final response = await _apiClient.get(
      '/api/documents/folders/$familyId',
      queryParameters: {
        'category': category,
        if (memberId != null) 'memberId': memberId,
      },
    );
    final folders = (response.data['folders'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return folders;
  }

  Future<void> createFolder({
    required String familyId,
    required String category,
    required String name,
    String? memberId,
  }) async {
    await _apiClient.post(
      '/api/documents/folders',
      data: {
        'familyId': familyId,
        'category': category,
        'name': name,
        'memberId': memberId,
      },
    );
  }

  Future<DocumentModel> moveDocumentToFolder({
    required String documentId,
    required String folder,
    String? memberId,
  }) async {
    final response = await _apiClient.patch(
      '/api/documents/$documentId/folder',
      data: {
        'folder': folder,
        if (memberId != null) 'memberId': memberId,
      },
    );
    return DocumentModel.fromJson(response.data);
  }
}
