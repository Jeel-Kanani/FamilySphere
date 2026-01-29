import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

/// Update Profile Use Case
/// 
/// Business Rule: Update user profile information
/// 
/// This use case:
/// 1. Validates the profile data
/// 2. Updates user in Firebase and local cache
/// 3. Returns updated User
class UpdateProfile {
  final AuthRepository repository;

  UpdateProfile(this.repository);

  /// Execute the use case
  /// 
  /// [userId] - ID of user to update
  /// [displayName] - New display name (optional)
  /// [photoUrl] - New photo URL (optional)
  /// 
  /// Returns updated User
  /// Throws exception if update fails
  Future<User> call({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {
    // Business rule: Validate display name if provided
    if (displayName != null && displayName.trim().isEmpty) {
      throw Exception('Display name cannot be empty');
    }

    if (displayName != null && displayName.length < 2) {
      throw Exception('Display name must be at least 2 characters');
    }

    // Delegate to repository
    return await repository.updateProfile(
      name: displayName?.trim() ?? '',
      email: null,
      photoUrl: photoUrl,
    );
  }
}
