class SyncHistoryEntryModel {
  final String id;
  final String familyId;
  final String itemType;
  final String itemId;
  final String action;
  final String status;
  final String message;
  final DateTime createdAt;

  const SyncHistoryEntryModel({
    required this.id,
    required this.familyId,
    required this.itemType,
    required this.itemId,
    required this.action,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory SyncHistoryEntryModel.fromJson(Map<String, dynamic> json) {
    return SyncHistoryEntryModel(
      id: json['id']?.toString() ?? '',
      familyId: json['familyId']?.toString() ?? '',
      itemType: json['itemType']?.toString() ?? 'document',
      itemId: json['itemId']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'itemType': itemType,
      'itemId': itemId,
      'action': action,
      'status': status,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
