/// User Entity - Core business object representing a user
/// 
/// This is a pure Dart class with no dependencies on Flutter or Firebase.
/// It represents the business concept of a "User" in FamilySphere.
class User {
  final String id;
  final String email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoUrl;
  final String? familyId;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? token; // JWT Token

  User({
    required this.id,
    required this.email,
    this.phoneNumber,
    this.displayName,
    this.photoUrl,
    this.familyId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.token,
  });

  /// Check if user has completed profile setup
  bool get hasCompletedProfile => displayName != null && displayName!.isNotEmpty;

  /// Check if user is part of a family
  bool get hasFamily => familyId != null && familyId!.isNotEmpty;

  /// Check if user is a family admin
  bool get isAdmin => role == UserRole.admin;

  /// Copy user with updated fields
  User copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    String? familyId,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? token,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      familyId: familyId ?? this.familyId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      token: token ?? this.token,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName, familyId: $familyId, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is User &&
      other.id == id &&
      other.email == email &&
      other.phoneNumber == phoneNumber &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.familyId == familyId &&
      other.role == role;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      email.hashCode ^
      phoneNumber.hashCode ^
      displayName.hashCode ^
      photoUrl.hashCode ^
      familyId.hashCode ^
      role.hashCode;
  }
}

/// User roles in a family
enum UserRole {
  admin,   // Can manage family, invite members, etc.
  member,  // Regular family member
}
