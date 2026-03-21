class ChatMessageEntity {
  final String id;
  final String familyId;
  final String senderId;
  final String senderName;
  final String content;
  final String type;
  final String? mediaUrl;
  final String status; // 'sent' | 'delivered' | 'read'
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const ChatMessageEntity({
    required this.id,
    required this.familyId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.status = 'sent',
    required this.createdAt,
    this.metadata = const {},
  });

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) {
    return ChatMessageEntity(
      id: json['_id'] ?? json['id'] ?? '',
      familyId: json['familyId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      mediaUrl: json['mediaUrl'],
      status: json['status'] ?? 'sent',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}
