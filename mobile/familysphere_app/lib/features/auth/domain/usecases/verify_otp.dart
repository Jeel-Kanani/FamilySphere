import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

/// Verify OTP Use Case
/// 
/// Business Rule: Verify the OTP code entered by the user
/// 
/// This use case:
/// 1. Validates the OTP code format
/// 2. Calls the repository to verify with Firebase
/// 3. Returns the authenticated User
class VerifyOtp {
  final AuthRepository repository;

  VerifyOtp(this.repository);

  /// Execute the use case
  /// 
  /// [verificationId] - ID received from SendOtp
  /// [otpCode] - 6-digit code entered by user
  /// 
  /// Returns authenticated User
  /// Throws exception if code is invalid or verification fails
  Future<User> call({
    required String verificationId,
    required String otpCode,
  }) async {
    // Business rule: Validate OTP code
    if (otpCode.isEmpty) {
      throw Exception('OTP code cannot be empty');
    }

    if (otpCode.length != 6) {
      throw Exception('OTP code must be 6 digits');
    }

    if (!RegExp(r'^\d+$').hasMatch(otpCode)) {
      throw Exception('OTP code must contain only numbers');
    }

    // Delegate to repository
    return await repository.verifyOtp(verificationId, otpCode);
  }
}
