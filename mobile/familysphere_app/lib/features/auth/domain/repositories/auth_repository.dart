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

  /// Send OTP to phone number
  Future<String> sendOtp({required String phoneNumber});

  /// Verify OTP and complete authentication
  Future<User> verifyOtp({
    required String verificationId,
    required String otp,
  });

  /// Sign in with Google
  Future<User> signInWithGoogle();

  /// Update user profile
  Future<User> updateProfile({
    required String name,
    String? email,
    String? photoUrl,
  });
}
