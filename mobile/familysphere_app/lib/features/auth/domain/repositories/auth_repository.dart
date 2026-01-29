import 'package:familysphere_app/features/auth/domain/entities/user.dart';

/// Authentication Repository Interface
abstract class AuthRepository {
  /// Register a new user
  Future<User> register({
    required String name,
    required String email,
    required String password,
  });

  /// Login with email and password
  Future<User> login({
    required String email,
    required String password,
  });

  /// Get the currently logged-in user
  Future<User?> getCurrentUser();

  /// Sign out the current user
  Future<void> signOut();

  // Deprecated/Removed methods:
  // sendOtp, verifyOtp, signInWithGoogle
}
