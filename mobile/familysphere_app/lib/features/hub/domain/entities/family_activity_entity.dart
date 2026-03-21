class FamilyActivityEntity {
  final String id;
  final String familyId;
  final String actorId;
  final String actorName;
  final String type;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const FamilyActivityEntity({
    required this.id,
    required this.familyId,
    required this.actorId,
    required this.actorName,
    required this.type,
    required this.message,
    required this.metadata,
    required this.createdAt,
  });

  factory FamilyActivityEntity.fromJson(Map<String, dynamic> json) {
    return FamilyActivityEntity(
      id: json['_id'] ?? json['id'] ?? '',
      familyId: json['familyId'] ?? '',
      actorId: json['actorId'] ?? '',
      actorName: json['actorName'] ?? '',
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
