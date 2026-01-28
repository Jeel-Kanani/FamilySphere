/// Family Member Entity
/// 
/// Represents a member of a family with their role and information
class FamilyMember {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final FamilyRole role;
  final DateTime joinedAt;

  FamilyMember({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.role,
    required this.joinedAt,
  });

  /// Check if member is admin
  bool get isAdmin => role == FamilyRole.admin;

  /// Copy with method for immutability
  FamilyMember copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    FamilyRole? role,
    DateTime? joinedAt,
  }) {
    return FamilyMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

/// Family Role Enum
/// 
/// Defines the role of a family member
enum FamilyRole {
  admin,
  member;

  String get displayName {
    switch (this) {
      case FamilyRole.admin:
        return 'Admin';
      case FamilyRole.member:
        return 'Member';
    }
  }
}
