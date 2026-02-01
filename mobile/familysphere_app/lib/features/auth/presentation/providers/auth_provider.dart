import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/core/services/token_service.dart';
import 'package:familysphere_app/features/auth/domain/entities/auth_state.dart';
import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:familysphere_app/features/auth/domain/usecases/login.dart';
import 'package:familysphere_app/features/auth/domain/usecases/register.dart';
import 'package:familysphere_app/features/auth/domain/usecases/get_current_user.dart';
import 'package:familysphere_app/features/auth/domain/usecases/sign_out.dart';
import 'package:familysphere_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:familysphere_app/features/auth/data/datasources/auth_remote_datasource.dart';

/// Dependency Injection - Core Services

// Token Service Provider
final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService();
});

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenService = ref.read(tokenServiceProvider);
  return ApiClient(tokenService: tokenService);
});

// Data Sources
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final tokenService = ref.read(tokenServiceProvider);
  return AuthRemoteDataSource(
    apiClient: apiClient,
    tokenService: tokenService,
  );
});

// Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.read(authRemoteDataSourceProvider),
  );
});

// Use Cases
final loginUseCaseProvider = Provider((ref) {
  return Login(ref.read(authRepositoryProvider));
});

final registerUseCaseProvider = Provider((ref) {
  return Register(ref.read(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider((ref) {
  return GetCurrentUser(ref.read(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider((ref) {
  return SignOut(ref.read(authRepositoryProvider));
});

/// Authentication State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Login _login;
  final Register _register;
  final GetCurrentUser _getCurrentUser;
  final SignOut _signOut;
  final AuthRepository _authRepository;

  AuthNotifier({
    required Login login,
    required Register register,
    required GetCurrentUser getCurrentUser,
    required SignOut signOut,
    required AuthRepository authRepository,
  })  : _login = login,
        _register = register,
        _getCurrentUser = getCurrentUser,
        _signOut = signOut,
        _authRepository = authRepository,
        super(AuthState.initial());

  /// Check if user is already logged in
  Future<void> checkAuthStatus() async {
    try {
      // ignore: avoid_print
      print('AuthNotifier: checkAuthStatus called');
      state = AuthState.loading();
      final user = await _getCurrentUser.call();
      if (user != null) {
        // ignore: avoid_print
        print('AuthNotifier: User found, authenticating');
        state = AuthState.authenticated(user);
      } else {
        // ignore: avoid_print
        print('AuthNotifier: No user found, initial state');
        state = AuthState.initial();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Auth check error: $e');
      state = AuthState.initial();
    }
  }

  /// Login with email/password
  Future<void> login(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final user = await _login.call(email: email, password: password);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Register new user
  Future<void> register(String name, String email, String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final user = await _register.call(name: name, email: email, password: password);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

  /// Update user profile (name, photo)
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final user = await _authRepository.updateProfile(
        name: displayName ?? state.user?.displayName ?? '',
        email: state.user?.email,
        photoUrl: photoUrl,
      );
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final verificationId = await _authRepository.sendOtp(phoneNumber: phoneNumber);
      state = state.copyWith(isLoading: false, verificationId: verificationId, status: AuthStatus.otpSent);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Verify OTP code
  Future<void> verifyOtp(String otp) async {
    try {
      if (state.verificationId == null) {
        throw Exception('No verification ID found');
      }
      state = state.copyWith(isLoading: true, error: null);
      final user = await _authRepository.verifyOtp(
        verificationId: state.verificationId!,
        otp: otp,
      );
      state = AuthState.authenticated(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final user = await _authRepository.signInWithGoogle();
      state = AuthState.authenticated(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh user data from backend
  Future<void> refreshUser() async {
    try {
      final user = await _getCurrentUser.call();
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Refresh user error: $e');
      // Don't update error state for background refresh
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth State Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    login: ref.read(loginUseCaseProvider),
    register: ref.read(registerUseCaseProvider),
    getCurrentUser: ref.read(getCurrentUserUseCaseProvider),
    signOut: ref.read(signOutUseCaseProvider),
    authRepository: ref.read(authRepositoryProvider),
  );
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
