
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';

class FamilyMemberModel extends FamilyMember {
  FamilyMemberModel({
    required super.userId,
    required super.displayName,
    super.photoUrl,
    required super.role,
    required super.joinedAt,
  });

  /// Create FamilyMemberModel from Domain Entity
  factory FamilyMemberModel.fromEntity(FamilyMember member) {
    return FamilyMemberModel(
      userId: member.userId,
      displayName: member.displayName,
      photoUrl: member.photoUrl,
      role: member.role,
      joinedAt: member.joinedAt,
    );
  }

  /// Create from Map (backend response)
  factory FamilyMemberModel.fromMap(Map<String, dynamic> map, String userId) {
    return FamilyMemberModel(
      userId: userId,
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      role: FamilyRole.values.firstWhere(
        (e) => e.name == (map['role'] ?? 'member'),
        orElse: () => FamilyRole.member,
      ),
      joinedAt: map['joinedAt'] != null 
          ? DateTime.parse(map['joinedAt']) 
          : DateTime.now(),
    );
  }

  /// Create from JSON (for Hive/Local storage)
  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      userId: json['userId'],
      displayName: json['displayName'],
      photoUrl: json['photoUrl'],
      role: FamilyRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => FamilyRole.member,
      ),
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }

  // Firestore methods removed

  /// Convert to JSON (for Hive/Local storage)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}
