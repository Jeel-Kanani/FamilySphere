import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/auth/domain/entities/auth_state.dart';
import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/usecases/send_otp.dart';
import 'package:familysphere_app/features/auth/domain/usecases/verify_otp.dart';
import 'package:familysphere_app/features/auth/domain/usecases/get_current_user.dart';
import 'package:familysphere_app/features/auth/domain/usecases/sign_out.dart';
import 'package:familysphere_app/features/auth/domain/usecases/update_profile.dart';
import 'package:familysphere_app/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:familysphere_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:familysphere_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:familysphere_app/features/auth/data/datasources/auth_local_datasource.dart';

/// Dependency Injection - Providers
/// 
/// These providers create and manage instances of our classes.
/// Riverpod handles the lifecycle and dependencies automatically.

// Data Sources
final authRemoteDataSourceProvider = Provider((ref) {
  return AuthRemoteDataSource();
});

final authLocalDataSourceProvider = Provider((ref) {
  return AuthLocalDataSource();
});

// Repository
final authRepositoryProvider = Provider((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.read(authRemoteDataSourceProvider),
    localDataSource: ref.read(authLocalDataSourceProvider),
  );
});

// Use Cases
final sendOtpUseCaseProvider = Provider((ref) {
  return SendOtp(ref.read(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider((ref) {
  return VerifyOtp(ref.read(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider((ref) {
  return GetCurrentUser(ref.read(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider((ref) {
  return SignOut(ref.read(authRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider((ref) {
  return UpdateProfile(ref.read(authRepositoryProvider));
});

final signInWithGoogleUseCaseProvider = Provider((ref) {
  return SignInWithGoogle(ref.read(authRepositoryProvider));
});

/// Authentication State Notifier
/// 
/// This class manages the authentication state and provides methods
/// for UI to trigger auth operations.
class AuthNotifier extends StateNotifier<AuthState> {
  final SendOtp _sendOtp;
  final VerifyOtp _verifyOtp;
  final GetCurrentUser _getCurrentUser;
  final SignOut _signOut;
  final UpdateProfile _updateProfile;
  final SignInWithGoogle _signInWithGoogle;

  AuthNotifier({
    required SendOtp sendOtp,
    required VerifyOtp verifyOtp,
    required GetCurrentUser getCurrentUser,
    required SignOut signOut,
    required UpdateProfile updateProfile,
    required SignInWithGoogle signInWithGoogle,
  })  : _sendOtp = sendOtp,
        _verifyOtp = verifyOtp,
        _getCurrentUser = getCurrentUser,
        _signOut = signOut,
        _updateProfile = updateProfile,
        _signInWithGoogle = signInWithGoogle,
        super(AuthState.initial());

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    try {
      print('📱 Sending OTP to: $phoneNumber');
      state = state.copyWith(
        status: AuthStatus.sendingOtp,
        isLoading: true,
        error: null,
      );

      final verificationId = await _sendOtp.call(phoneNumber);
      print('✅ OTP sent! Verification ID: $verificationId');

      state = AuthState.otpSent(verificationId);
      print('📊 State updated. Verification ID in state: ${state.verificationId}');
    } catch (e) {
      print('❌ Send OTP error: $e');
      state = AuthState.error(e.toString());
    }
  }

  /// Verify OTP code
  Future<void> verifyOtp(String otpCode) async {
    try {
      print('🔐 Verifying OTP: $otpCode');
      print('📊 Current state verification ID: ${state.verificationId}');
      
      if (state.verificationId == null) {
        print('❌ No verification ID in state!');
        state = AuthState.error('No verification ID found. Please request OTP again.');
        return;
      }

      state = state.copyWith(
        status: AuthStatus.verifyingOtp,
        isLoading: true,
        error: null,
      );

      final user = await _verifyOtp.call(
        verificationId: state.verificationId!,
        otpCode: otpCode,
      );

      print('✅ OTP verified! User: ${user.phoneNumber}');
      state = AuthState.authenticated(user);
    } catch (e) {
      print('❌ Verify OTP error: $e');
      state = AuthState.error(e.toString());
    }
  }

  /// Check if user is already logged in
  Future<void> checkAuthStatus() async {
    try {
      state = AuthState.loading();

      final user = await _getCurrentUser.call();

      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.initial();
      }
    } catch (e) {
      state = AuthState.initial();
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      if (state.user == null) {
        state = AuthState.error('No user logged in');
        return;
      }

      state = state.copyWith(isLoading: true, error: null);

      final updatedUser = await _updateProfile.call(
        userId: state.user!.id,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      state = AuthState.authenticated(updatedUser);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _signOut.call();
      state = AuthState.initial();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In from provider...');
      state = state.copyWith(
        status: AuthStatus.sendingOtp, // Reusing this for loading state
        isLoading: true,
        error: null,
      );

      // Call use case
      final user = await _signInWithGoogle.call();
      
      print('✅ Google Sign-In successful! User: ${user.displayName}');
      state = AuthState.authenticated(user);
    } catch (e) {
      print('❌ Google Sign-In error in provider: $e');
      if (e.toString().contains('canceled')) {
        // User canceled - just reset to initial, don't show error
        state = AuthState.initial();
      } else {
        state = AuthState.error(e.toString());
      }
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth State Provider
/// 
/// This is the main provider that UI will use to:
/// 1. Read auth state
/// 2. Trigger auth operations
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    sendOtp: ref.read(sendOtpUseCaseProvider),
    verifyOtp: ref.read(verifyOtpUseCaseProvider),
    getCurrentUser: ref.read(getCurrentUserUseCaseProvider),
    signOut: ref.read(signOutUseCaseProvider),
    updateProfile: ref.read(updateProfileUseCaseProvider),
    signInWithGoogle: ref.read(signInWithGoogleUseCaseProvider),
  );
});

/// Current User Provider
/// 
/// Convenient provider to get just the current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Is Authenticated Provider
/// 
/// Convenient provider to check if user is logged in
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
