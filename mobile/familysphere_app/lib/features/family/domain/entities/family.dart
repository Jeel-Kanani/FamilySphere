/// Family Entity
/// 
/// Represents a family group in the application.
/// Contains family information and member management logic.
class Family {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final List<String> memberIds;
  final String inviteCode;
  final FamilySettings settings;

  Family({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.memberIds,
    required this.inviteCode,
    required this.settings,
  });

  /// Check if user is admin (creator)
  bool isAdmin(String userId) => createdBy == userId;

  /// Check if user is a member
  bool isMember(String userId) => memberIds.contains(userId);

  /// Check if user can invite members
  bool canInvite(String userId) {
    if (isAdmin(userId)) return true;
    return settings.allowMemberInvites && isMember(userId);
  }

  /// Check if user can remove a member
  bool canRemoveMember(String userId, String targetUserId) {
    // Only admin can remove members
    // Cannot remove self (use leave instead)
    // Cannot remove the admin
    return isAdmin(userId) && 
           userId != targetUserId && 
           targetUserId != createdBy;
  }

  /// Get member count
  int get memberCount => memberIds.length;

  /// Copy with method for immutability
  Family copyWith({
    String? id,
    String? name,
    String? createdBy,
    DateTime? createdAt,
    List<String>? memberIds,
    String? inviteCode,
    FamilySettings? settings,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
      inviteCode: inviteCode ?? this.inviteCode,
      settings: settings ?? this.settings,
    );
  }
}

/// Family Settings
/// 
/// Configuration options for a family
class FamilySettings {
  final bool allowMemberInvites;
  final bool requireApproval;

  const FamilySettings({
    this.allowMemberInvites = true,
    this.requireApproval = false,
  });

  FamilySettings copyWith({
    bool? allowMemberInvites,
    bool? requireApproval,
  }) {
    return FamilySettings(
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      requireApproval: requireApproval ?? this.requireApproval,
    );
  }
}
