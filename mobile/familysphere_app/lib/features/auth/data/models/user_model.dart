import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familysphere_app/features/auth/domain/entities/user.dart';

/// User Model - Data Transfer Object
/// 
/// This class extends the User entity and adds:
/// 1. JSON serialization (toJson/fromJson)
/// 2. Firebase conversion (toFirestore/fromFirestore)
/// 
/// Why separate from Entity?
/// - Entity = Pure business logic (no dependencies)
/// - Model = Data transfer (knows about JSON, Firebase, etc.)
class UserModel extends User {
  UserModel({
    required super.id,
    required super.phoneNumber,
    super.displayName,
    super.photoUrl,
    super.familyId,
    required super.role,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create UserModel from Entity
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      familyId: user.familyId,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  /// Convert to JSON (for local storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'familyId': familyId,
      'role': role.name, // Convert enum to string
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (from local storage)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      familyId: json['familyId'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.member,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'familyId': familyId,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore document
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return UserModel(
      id: snapshot.id, // Document ID is the user ID
      phoneNumber: data['phoneNumber'] as String,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      familyId: data['familyId'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.member,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Create a new user (for registration)
  factory UserModel.create({
    required String id,
    required String phoneNumber,
    String? displayName,
    String? photoUrl,
  }) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      phoneNumber: phoneNumber,
      displayName: displayName,
      photoUrl: photoUrl,
      role: UserRole.member, // Default role
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Copy with updated fields (returns UserModel, not User)
  @override
  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    String? familyId,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      familyId: familyId ?? this.familyId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
