import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

/// Send OTP Use Case
/// 
/// Business Rule: Send a one-time password to the user's phone number
/// 
/// This use case:
/// 1. Validates the phone number format
/// 2. Calls the repository to send OTP via Firebase
/// 3. Returns a verification ID for later verification
/// 
/// Why a separate use case?
/// - Single Responsibility: Only handles sending OTP
/// - Testable: Easy to test business logic
/// - Reusable: Can be called from anywhere
class SendOtp {
  final AuthRepository repository;

  SendOtp(this.repository);

  /// Execute the use case
  /// 
  /// [phoneNumber] - Phone number with country code (e.g., +911234567890)
  /// 
  /// Returns verification ID
  /// Throws exception if phone number is invalid or sending fails
  Future<String> call(String phoneNumber) async {
    // Business rule: Validate phone number
    if (phoneNumber.isEmpty) {
      throw Exception('Phone number cannot be empty');
    }

    if (!phoneNumber.startsWith('+')) {
      throw Exception('Phone number must include country code (e.g., +91)');
    }

    // Delegate to repository
    return await repository.sendOtp(phoneNumber: phoneNumber);
  }
}
