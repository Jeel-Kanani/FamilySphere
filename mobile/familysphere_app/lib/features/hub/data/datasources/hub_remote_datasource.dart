import 'package:familysphere_app/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/family_activity_entity.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart' show apiClientProvider;

class HubRemoteDataSource {
  final ApiClient _apiClient;

  HubRemoteDataSource(this._apiClient);

  Future<List<PostEntity>> getFeed(String familyId) async {
    final response = await _apiClient.get('/api/hub/feed/$familyId');
    final List<dynamic> data = response.data;
    return data.map((json) => PostEntity.fromJson(json)).toList();
  }

  Future<PostEntity> createPost({
    required String familyId,
    required String content,
    List<String> mediaUrls = const [],
    required String type,
  }) async {
    final response = await _apiClient.post('/api/hub/feed', data: {
      'familyId': familyId,
      'content': content,
      'mediaUrls': mediaUrls,
      'type': type,
    });
    return PostEntity.fromJson(response.data);
  }

  Future<PostEntity> toggleLike(String postId) async {
    final response = await _apiClient.post('/api/hub/feed/$postId/like');
    return PostEntity.fromJson(response.data);
  }

  Future<List<FamilyActivityEntity>> getActivities(String familyId) async {
    final response = await _apiClient.get('/api/hub/activity/$familyId');
    final List<dynamic> data = response.data;
    return data.map((json) => FamilyActivityEntity.fromJson(json)).toList();
  }
}

final hubRemoteDataSourceProvider = Provider<HubRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HubRemoteDataSource(apiClient);
});
