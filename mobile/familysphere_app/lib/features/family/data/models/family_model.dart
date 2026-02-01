
import 'package:familysphere_app/features/family/domain/entities/family.dart';

class FamilyModel extends Family {
  FamilyModel({
    required super.id,
    required super.name,
    required super.createdBy,
    required super.createdAt,
    required super.memberIds,
    required super.inviteCode,
    required super.settings,
  });

  /// Create FamilyModel from Domain Entity
  factory FamilyModel.fromEntity(Family family) {
    return FamilyModel(
      id: family.id,
      name: family.name,
      createdBy: family.createdBy,
      createdAt: family.createdAt,
      memberIds: family.memberIds,
      inviteCode: family.inviteCode,
      settings: family.settings,
    );
  }

  // Firestore methods removed

  /// Create FamilyModel from JSON (for Hive/Local storage)
  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      memberIds: json['memberIds'] != null 
          ? List<String>.from(json['memberIds']) 
          : [],
      inviteCode: json['inviteCode'] ?? '',
      settings: json['settings'] != null 
          ? FamilySettingsModel.fromMap(json['settings']) 
          : const FamilySettingsModel(),
    );
  }


  /// Convert to JSON (for Hive/Local storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'memberIds': memberIds,
      'inviteCode': inviteCode,
      'settings': (settings as FamilySettingsModel).toMap(),
    };
  }
}

class FamilySettingsModel extends FamilySettings {
  const FamilySettingsModel({
    super.allowMemberInvites,
    super.requireApproval,
  });

  factory FamilySettingsModel.fromMap(Map<String, dynamic> map) {
    return FamilySettingsModel(
      allowMemberInvites: map['allowMemberInvites'] ?? true,
      requireApproval: map['requireApproval'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowMemberInvites': allowMemberInvites,
      'requireApproval': requireApproval,
    };
  }
}
