import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

/// Sign Out Use Case
/// 
/// Business Rule: Sign out the current user
/// 
/// This use case:
/// 1. Clears Firebase authentication session
/// 2. Clears local cache
/// 3. Returns user to login screen
class SignOut {
  final AuthRepository repository;

  SignOut(this.repository);

  /// Execute the use case
  /// 
  /// Throws exception if sign out fails
  Future<void> call() async {
    await repository.signOut();
  }
}
