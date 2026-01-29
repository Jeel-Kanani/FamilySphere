import 'package:familysphere_app/features/auth/domain/entities/user.dart';

/// User Model - Data Transfer Object
class UserModel extends User {
  UserModel({
    required super.id,
    required super.email,
    super.phoneNumber,
    super.displayName,
    super.photoUrl,
    super.familyId,
    required super.role,
    required super.createdAt,
    required super.updatedAt,
    super.token,
  });

  /// Create UserModel from Entity
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      familyId: user.familyId,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      token: user.token,
    );
  }

  /// Convert to JSON (for local storage and API)
  Map<String, dynamic> toJson() {
    return {
      '_id': id, // Backend uses _id
      'email': email,
      'name': displayName, // Backend uses name
      'photoUrl': photoUrl,
      'familyId': familyId,
      'role': role.name,
      'token': token,
      // 'createdAt': createdAt.toIso8601String(), // Optional if needed
      // 'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (from API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] as String,
      email: json['email'] as String,
      displayName: json['name'] as String?, // Map 'name' to 'displayName'
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      familyId: json['familyId'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.member,
      ),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
      token: json['token'] as String?,
    );
  }

  // Deprecated/Modified Firestore methods if needed, or remove them.
  // Keeping them for now in case we want to sync, but likely not needed for pure MongoDB.
  // I will remove Firestore specific methods to be clean, as requested "instead of Firebase".
}
