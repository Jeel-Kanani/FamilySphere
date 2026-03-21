class PostEntity {
  final String id;
  final String familyId;
  final String creatorId;
  final String content;
  final List<String> mediaUrls;
  final String type; // 'moment' | 'milestone' | 'document_share'
  final List<String> likes;
  final DateTime createdAt;

  const PostEntity({
    required this.id,
    required this.familyId,
    required this.creatorId,
    required this.content,
    required this.mediaUrls,
    required this.type,
    required this.likes,
    required this.createdAt,
  });

  factory PostEntity.fromJson(Map<String, dynamic> json) {
    return PostEntity(
      id: json['_id'] ?? json['id'] ?? '',
      familyId: json['familyId'] ?? '',
      creatorId: json['creatorId'] ?? '',
      content: json['content'] ?? '',
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
      type: json['type'] ?? 'moment',
      likes: List<String>.from(json['likes'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
