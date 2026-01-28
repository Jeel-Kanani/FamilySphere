import 'package:familysphere_app/features/auth/domain/entities/user.dart';

/// Authentication Repository Interface
/// 
/// This is a CONTRACT that defines what authentication operations are available.
/// The actual implementation will be in the data layer.
/// 
/// Why use an interface?
/// - Separates "what we need" from "how we do it"
/// - Makes testing easier (we can mock this)
/// - Allows switching implementations (Firebase, REST API, etc.)
abstract class AuthRepository {
  /// Send OTP to the given phone number
  /// 
  /// Returns a verification ID that will be used to verify the OTP
  /// Throws an exception if sending fails
  Future<String> sendOtp(String phoneNumber);

  /// Verify the OTP code
  /// 
  /// [verificationId] - ID received from sendOtp
  /// [otpCode] - 6-digit code entered by user
  /// 
  /// Returns the authenticated User
  /// Throws an exception if verification fails
  Future<User> verifyOtp(String verificationId, String otpCode);

  /// Get the currently logged-in user
  /// 
  /// Returns null if no user is logged in
  /// Checks both Firebase Auth and local cache
  Future<User?> getCurrentUser();

  /// Update user profile information
  /// 
  /// [userId] - ID of user to update
  /// [displayName] - New display name (optional)
  /// [photoUrl] - New photo URL (optional)
  /// 
  /// Returns updated User
  Future<User> updateProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
  });

  /// Sign out the current user
  /// 
  /// Clears Firebase Auth session and local cache
  Future<void> signOut();

  /// Sign in with Google
  /// 
  /// Returns User if sign-in successful
  /// Throws exception if sign-in fails or canceled
  Future<User> signInWithGoogle();

  /// Stream of authentication state changes
  /// 
  /// Emits a new User whenever auth state changes
  /// Emits null when user signs out
  Stream<User?> get authStateChanges;
}
