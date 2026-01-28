import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Create FamilyModel from Firestore Document
  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FamilyModel(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      inviteCode: data['inviteCode'] ?? '',
      settings: FamilySettingsModel.fromMap(data['settings'] ?? {}),
    );
  }

  /// Create FamilyModel from JSON (for Hive/Local storage)
  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['id'],
      name: json['name'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
      memberIds: List<String>.from(json['memberIds']),
      inviteCode: json['inviteCode'],
      settings: FamilySettingsModel.fromMap(json['settings']),
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberIds': memberIds,
      'inviteCode': inviteCode,
      'settings': (settings as FamilySettingsModel).toMap(),
    };
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
