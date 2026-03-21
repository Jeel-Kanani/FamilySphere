import 'package:familysphere_app/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_message_entity.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart' show apiClientProvider;

class ChatRemoteDataSource {
  final ApiClient _apiClient;

  ChatRemoteDataSource(this._apiClient);

  Future<List<ChatMessageEntity>> getMessages(String familyId) async {
    final response = await _apiClient.get('/api/chat/$familyId');
    final List<dynamic> data = response.data;
    return data.map((json) => ChatMessageEntity.fromJson(json)).toList();
  }

  Future<ChatMessageEntity> sendMessage({
    required String familyId,
    required String content,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _apiClient.post('/api/chat', data: {
      'familyId': familyId,
      'content': content,
      'type': type,
      'metadata': metadata ?? {},
    });
    return ChatMessageEntity.fromJson(response.data);
  }
}

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRemoteDataSource(apiClient);
});
