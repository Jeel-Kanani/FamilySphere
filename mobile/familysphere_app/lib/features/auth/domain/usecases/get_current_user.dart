import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

/// Get Current User Use Case
/// 
/// Business Rule: Retrieve the currently authenticated user
/// 
/// This use case:
/// 1. Checks if a user is logged in
/// 2. Returns the user from cache or Firebase
/// 3. Returns null if no user is logged in
class GetCurrentUser {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  /// Execute the use case
  /// 
  /// Returns current User or null if not authenticated
  Future<User?> call() async {
    return await repository.getCurrentUser();
  }
}
