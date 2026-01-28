import 'package:familysphere_app/features/auth/domain/entities/user.dart';

/// Authentication State - Represents the current authentication status
/// 
/// This enum-like class helps manage different states during the auth flow.
/// Used by the presentation layer to show appropriate UI.
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final String? verificationId;  // For OTP verification
  final bool isLoading;

  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.verificationId,
    this.isLoading = false,
  });

  /// Initial state - not authenticated
  factory AuthState.initial() {
    return const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
    );
  }

  /// Loading state - processing authentication
  factory AuthState.loading() {
    return const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: true,
    );
  }

  /// OTP sent successfully
  factory AuthState.otpSent(String verificationId) {
    return AuthState(
      status: AuthStatus.otpSent,
      verificationId: verificationId,
      isLoading: false,
    );
  }

  /// User authenticated successfully
  factory AuthState.authenticated(User user) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      isLoading: false,
    );
  }

  /// Authentication error
  factory AuthState.error(String error) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      error: error,
      isLoading: false,
    );
  }

  /// Copy state with updated fields
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    String? verificationId,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
      verificationId: verificationId ?? this.verificationId,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() {
    return 'AuthState(status: $status, user: $user, error: $error, isLoading: $isLoading)';
  }
}

/// Authentication status enum
enum AuthStatus {
  unauthenticated,  // Not logged in
  sendingOtp,       // Sending OTP to phone
  otpSent,          // OTP sent successfully
  verifyingOtp,     // Verifying OTP code
  authenticated,    // Successfully authenticated
}
