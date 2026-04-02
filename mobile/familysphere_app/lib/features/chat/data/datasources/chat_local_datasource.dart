import 'package:familysphere_app/features/chat/data/models/chat_queue_item_model.dart';
import 'package:familysphere_app/features/chat/domain/entities/chat_message_entity.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChatLocalDataSource {
  static const String _messagesBox = 'chat_messages_box';
  static const String _queueBox = 'chat_queue_box';

  Future<void> init() async {
    if (!Hive.isBoxOpen(_messagesBox)) {
      await Hive.openBox<dynamic>(_messagesBox);
    }
    if (!Hive.isBoxOpen(_queueBox)) {
      await Hive.openBox<dynamic>(_queueBox);
    }
  }

  Future<Box<dynamic>> _openMessagesBox() async {
    return Hive.openBox<dynamic>(_messagesBox);
  }

  Future<Box<dynamic>> _openQueueBox() async {
    return Hive.openBox<dynamic>(_queueBox);
  }

  Future<void> cacheMessages(
    String familyId,
    List<ChatMessageEntity> messages,
  ) async {
    final box = await _openMessagesBox();
    await box.put(
      familyId,
      messages.map((message) => message.toJson()).toList(),
    );
  }

  Future<List<ChatMessageEntity>> getCachedMessages(String familyId) async {
    final box = await _openMessagesBox();
    final raw = box.get(familyId);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ChatMessageEntity.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> upsertMessage(ChatMessageEntity message) async {
    final existing = await getCachedMessages(message.familyId);
    final updated = [
      ...existing.where((item) => item.id != message.id),
      message,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await cacheMessages(message.familyId, updated);
  }

  Future<void> replaceQueuedMessageId({
    required String familyId,
    required String tempId,
    required ChatMessageEntity serverMessage,
  }) async {
    final existing = await getCachedMessages(familyId);
    final updated = existing
        .map((item) => item.id == tempId ? serverMessage : item)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await cacheMessages(familyId, updated);
  }

  Future<void> saveQueueItem(ChatQueueItemModel item) async {
    final box = await _openQueueBox();
    await box.put(item.id, item.toJson());
  }

  Future<void> removeQueueItem(String id) async {
    final box = await _openQueueBox();
    await box.delete(id);
  }

  Future<List<ChatQueueItemModel>> getQueueItems(String familyId) async {
    final box = await _openQueueBox();
    return box.values
        .whereType<Map>()
        .map((item) => ChatQueueItemModel.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.familyId == familyId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
}
