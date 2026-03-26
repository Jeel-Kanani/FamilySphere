class DocumentSyncJobModel {
  final String id;
  final String familyId;
  final String type; // upload | delete | move
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const DocumentSyncJobModel({
    required this.id,
    required this.familyId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory DocumentSyncJobModel.fromJson(Map<String, dynamic> json) {
    return DocumentSyncJobModel(
      id: json['id']?.toString() ?? '',
      familyId: json['familyId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
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
      'type': type,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  DocumentSyncJobModel copyWith({
    String? id,
    String? familyId,
    String? type,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
  }) {
    return DocumentSyncJobModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
