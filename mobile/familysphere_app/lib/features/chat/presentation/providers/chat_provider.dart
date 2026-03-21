import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/core/services/socket_service.dart';

class ChatState {
  final List<ChatMessageEntity> messages;
  final bool isLoading;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessageEntity>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}


class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRemoteDataSource _dataSource;
  final Ref _ref;

  ChatNotifier(this._dataSource, this._ref) : super(ChatState());

  void initSocketListeners() {
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    final socketService = _ref.read(socketServiceProvider);
    socketService.joinFamily(familyId);

    socketService.on('new_message', (data) {
      final newMessage = ChatMessageEntity.fromJson(data);
      // Check for duplicates (e.g. if we already added it via REST call)
      if (!state.messages.any((m) => m.id == newMessage.id)) {
        state = state.copyWith(messages: [...state.messages, newMessage]);
      }
    });
  }

  Future<void> loadMessages() async {
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _dataSource.getMessages(familyId);
      state = state.copyWith(messages: messages, isLoading: false);
      
      // Also ensure listeners are active
      initSocketListeners();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage({
    required String content,
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;

    try {
      final message = await _dataSource.sendMessage(
        familyId: user!.familyId!,
        content: content,
        type: type,
        metadata: metadata,
      );
      // Optionally add here for optimistic UI, or let the socket broadcast handle it.
      // Since we have the ID from the response, we add it and the socket listener 
      // will skip it because of the 'contains' check.
      if (!state.messages.any((m) => m.id == message.id)) {
        state = state.copyWith(messages: [...state.messages, message]);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final dataSource = ref.watch(chatRemoteDataSourceProvider);
  return ChatNotifier(dataSource, ref);
});
