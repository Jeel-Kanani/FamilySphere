import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/chat_local_datasource.dart';
import '../../data/models/chat_queue_item_model.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/core/services/socket_service.dart';
import 'package:familysphere_app/core/providers/network_status_provider.dart';

class ChatState {
  final List<ChatMessageEntity> messages;
  final bool isLoading;
  final String? error;
  final int pendingQueueCount;
  final Map<String, String> queuedErrorsByMessageId;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.pendingQueueCount = 0,
    this.queuedErrorsByMessageId = const {},
  });

  ChatState copyWith({
    List<ChatMessageEntity>? messages,
    bool? isLoading,
    String? error,
    int? pendingQueueCount,
    Map<String, String>? queuedErrorsByMessageId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      pendingQueueCount: pendingQueueCount ?? this.pendingQueueCount,
      queuedErrorsByMessageId:
          queuedErrorsByMessageId ?? this.queuedErrorsByMessageId,
    );
  }
}

final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  return ChatLocalDataSource();
});

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRemoteDataSource _dataSource;
  final ChatLocalDataSource _localDataSource;
  final Ref _ref;
  bool _listenersInitialized = false;

  ChatNotifier(this._dataSource, this._localDataSource, this._ref)
      : super(ChatState());

  List<ChatMessageEntity> _mergeMessages(
    List<ChatMessageEntity> remoteMessages,
    List<ChatMessageEntity> cachedMessages,
  ) {
    final mergedById = <String, ChatMessageEntity>{
      for (final message in remoteMessages) message.id: message,
    };

    for (final message in cachedMessages) {
      if (message.id.startsWith('local-chat-')) {
        mergedById[message.id] = message;
      }
    }

    final merged = mergedById.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void initSocketListeners() {
    if (_listenersInitialized) return;
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    final socketService = _ref.read(socketServiceProvider);
    socketService.joinFamily(familyId);
    _listenersInitialized = true;

    socketService.on('new_message', (data) {
      final newMessage = ChatMessageEntity.fromJson(data);
      // Check for duplicates (e.g. if we already added it via REST call)
      if (!state.messages.any((m) => m.id == newMessage.id)) {
        state = state.copyWith(messages: [...state.messages, newMessage]);
      }
      _localDataSource.upsertMessage(newMessage);
    });
  }

  Future<void> loadMessages() async {
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    final cached = await _localDataSource.getCachedMessages(familyId);
    final queueItems = await _localDataSource.getQueueItems(familyId);
    state = state.copyWith(
      messages: cached,
      pendingQueueCount: queueItems.length,
      queuedErrorsByMessageId: {
        for (final item in queueItems)
          'local-chat-${item.id}': item.lastError ?? '',
      },
    );

    state = state.copyWith(isLoading: true, error: null);
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      state = state.copyWith(isLoading: false);
      initSocketListeners();
      return;
    }

    try {
      final messages = await _dataSource.getMessages(familyId);
      final mergedMessages = _mergeMessages(messages, cached);
      await _localDataSource.cacheMessages(familyId, mergedMessages);
      state = state.copyWith(messages: mergedMessages, isLoading: false);

      // Also ensure listeners are active
      initSocketListeners();
      if (queueItems.isNotEmpty) {
        await syncPendingMessages();
      }
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

    final tempId = 'local-chat-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticMessage = ChatMessageEntity(
      id: tempId,
      familyId: user!.familyId!,
      senderId: user.id,
      senderName: user.displayName ?? user.email,
      content: content,
      type: type,
      status: 'pending_sync',
      createdAt: DateTime.now(),
      metadata: metadata ?? const {},
    );
    final updatedMessages = [...state.messages, optimisticMessage]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: updatedMessages, error: null);
    await _localDataSource.upsertMessage(optimisticMessage);

    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      final queueItem = ChatQueueItemModel(
        id: tempId.replaceFirst('local-chat-', ''),
        familyId: user.familyId!,
        content: content,
        type: type,
        metadata: metadata ?? const {},
        createdAt: optimisticMessage.createdAt,
      );
      await _localDataSource.saveQueueItem(queueItem);
      state = state.copyWith(
        pendingQueueCount: state.pendingQueueCount + 1,
        queuedErrorsByMessageId: {
          ...state.queuedErrorsByMessageId,
          tempId: '',
        },
      );
      return;
    }

    try {
      final message = await _dataSource.sendMessage(
        familyId: user.familyId!,
        content: content,
        type: type,
        metadata: metadata,
      );
      final finalMessages = state.messages
          .map((item) => item.id == tempId ? message : item)
          .toList();
      state = state.copyWith(messages: finalMessages);
      await _localDataSource.replaceQueuedMessageId(
        familyId: user.familyId!,
        tempId: tempId,
        serverMessage: message,
      );
    } catch (e) {
      final queueItem = ChatQueueItemModel(
        id: tempId.replaceFirst('local-chat-', ''),
        familyId: user.familyId!,
        content: content,
        type: type,
        metadata: metadata ?? const {},
        createdAt: optimisticMessage.createdAt,
        lastError: e.toString(),
      );
      await _localDataSource.saveQueueItem(queueItem);
      state = state.copyWith(
        pendingQueueCount: state.pendingQueueCount + 1,
        queuedErrorsByMessageId: {
          ...state.queuedErrorsByMessageId,
          tempId: e.toString(),
        },
        error: e.toString(),
      );
    }
  }

  Future<void> syncPendingMessages() async {
    final user = _ref.read(authProvider).user;
    if (user?.familyId == null) return;
    if (!_ref.read(isOnlineProvider)) return;

    final queueItems = await _localDataSource.getQueueItems(user!.familyId!);
    if (queueItems.isEmpty) {
      state = state.copyWith(
        pendingQueueCount: 0,
        queuedErrorsByMessageId: const {},
      );
      return;
    }

    final queuedErrors =
        Map<String, String>.from(state.queuedErrorsByMessageId);
    for (final item in queueItems) {
      final tempId = 'local-chat-${item.id}';
      try {
        final serverMessage = await _dataSource.sendMessage(
          familyId: item.familyId,
          content: item.content,
          type: item.type,
          metadata: item.metadata,
        );
        state = state.copyWith(
          messages: state.messages
              .map((message) => message.id == tempId ? serverMessage : message)
              .toList(),
        );
        await _localDataSource.replaceQueuedMessageId(
          familyId: item.familyId,
          tempId: tempId,
          serverMessage: serverMessage,
        );
        await _localDataSource.removeQueueItem(item.id);
        queuedErrors.remove(tempId);
      } catch (e) {
        final updatedItem =
            item.copyWith(retryCount: item.retryCount + 1, lastError: '$e');
        await _localDataSource.saveQueueItem(updatedItem);
        queuedErrors[tempId] = '$e';
      }
    }

    final remaining = await _localDataSource.getQueueItems(user.familyId!);
    state = state.copyWith(
      pendingQueueCount: remaining.length,
      queuedErrorsByMessageId: queuedErrors,
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final dataSource = ref.watch(chatRemoteDataSourceProvider);
  final localDataSource = ref.watch(chatLocalDataSourceProvider);
  return ChatNotifier(dataSource, localDataSource, ref);
});
