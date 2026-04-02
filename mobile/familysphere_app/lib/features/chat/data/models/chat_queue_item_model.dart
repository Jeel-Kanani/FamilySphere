class ChatQueueItemModel {
  final String id;
  final String familyId;
  final String content;
  final String type;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const ChatQueueItemModel({
    required this.id,
    required this.familyId,
    required this.content,
    required this.type,
    required this.metadata,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory ChatQueueItemModel.fromJson(Map<String, dynamic> json) {
    return ChatQueueItemModel(
      id: json['id']?.toString() ?? '',
      familyId: json['familyId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'content': content,
      'type': type,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  ChatQueueItemModel copyWith({
    String? id,
    String? familyId,
    String? content,
    String? type,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
  }) {
    return ChatQueueItemModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      content: content ?? this.content,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
