class FamilyActivity {
  final String id;
  final String type;
  final String message;
  final String? actorName;
  final DateTime createdAt;

  FamilyActivity({
    required this.id,
    required this.type,
    required this.message,
    this.actorName,
    required this.createdAt,
  });
}
