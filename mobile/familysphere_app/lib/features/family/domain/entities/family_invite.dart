/// Family Invite Entity
class FamilyInvite {
  final String id;
  final String familyId;
  final String type; // qr, code, link
  final String token;
  final String? code;
  final String createdBy;
  final DateTime expiresAt;
  final int maxUses;
  final int usedCount;

  FamilyInvite({
    required this.id,
    required this.familyId,
    required this.type,
    required this.token,
    this.code,
    required this.createdBy,
    required this.expiresAt,
    required this.maxUses,
    required this.usedCount,
  });

  factory FamilyInvite.fromJson(Map<String, dynamic> json) {
    return FamilyInvite(
      id: json['_id'] ?? json['id'],
      familyId: json['familyId'],
      type: json['type'],
      token: json['token'],
      code: json['code'],
      createdBy: json['createdBy'],
      expiresAt: DateTime.parse(json['expiresAt']),
      maxUses: json['maxUses'] ?? 1,
      usedCount: json['usedCount'] ?? 0,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isFull => usedCount >= maxUses;
  bool get isValid => !isExpired && !isFull;
}
