import 'package:familysphere_app/core/config/api_config.dart';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/core/services/token_service.dart';
import 'package:familysphere_app/features/auth/data/models/user_model.dart';
import 'package:familysphere_app/features/auth/data/models/login_request.dart';
import 'package:familysphere_app/features/auth/data/models/register_request.dart';

class AuthRemoteDataSource {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  AuthRemoteDataSource({
    required ApiClient apiClient,
    required TokenService tokenService,
  })  : _apiClient = apiClient,
        _tokenService = tokenService;

  /// Register new user
  Future<UserModel> register(String name, String email, String password) async {
    try {
      final request = RegisterRequest(
        name: name,
        email: email,
        password: password,
      );

      final response = await _apiClient.post(
        ApiConfig.registerEndpoint,
        data: request.toJson(),
      );

      // Parse response
      final userModel = UserModel.fromJson(response.data);

      // Save token and user data to secure storage
      if (userModel.token != null) {
        await _tokenService.saveToken(userModel.token!);
        await _tokenService.saveUserData(
          userId: userModel.id,
          email: userModel.email,
          name: userModel.displayName ?? name,
        );
      }

      return userModel;
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  /// Login user
  Future<UserModel> login(String email, String password) async {
    try {
      final request = LoginRequest(
        email: email,
        password: password,
      );

      final response = await _apiClient.post(
        ApiConfig.loginEndpoint,
        data: request.toJson(),
      );

      // Parse response
      final userModel = UserModel.fromJson(response.data);

      // Save token and user data to secure storage
      if (userModel.token != null) {
        await _tokenService.saveToken(userModel.token!);
        await _tokenService.saveUserData(
          userId: userModel.id,
          email: userModel.email,
          name: userModel.displayName ?? email,
        );
      }

      return userModel;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Get current user from backend (requires valid token)
  Future<UserModel?> getCurrentUser() async {
    try {
      // Check if token exists
      final isLoggedIn = await _tokenService.isLoggedIn();
      if (!isLoggedIn) {
        return null;
      }

      // Fetch current user from backend
      final response = await _apiClient.get(ApiConfig.currentUserEndpoint);

      // Parse response
      final userModel = UserModel.fromJson(response.data);
      return userModel;
    } catch (e) {
      // If token is invalid, clear storage
      await _tokenService.clearUserData();
      return null;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      // Clear all user data from secure storage
      await _tokenService.clearUserData();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile(String name, String? email, String? photoUrl) async {
    try {
      final data = <String, dynamic>{'name': name};
      if (email != null) data['email'] = email;
      if (photoUrl != null) data['photoUrl'] = photoUrl;

      final response = await _apiClient.put(
        ApiConfig.updateProfileEndpoint,
        data: data,
      );

      // Parse updated user
      final userModel = UserModel.fromJson(response.data);

      // Update local storage
      await _tokenService.saveUserData(
        userId: userModel.id,
        email: userModel.email,
        name: userModel.displayName ?? '',
      );

      return userModel;
    } catch (e) {
      throw Exception('Profile update failed: ${e.toString()}');
    }
  }

  /// Send OTP to phone number
  Future<String> sendOtp(String phoneNumber) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/send-otp',
        data: {'phoneNumber': phoneNumber},
      );
      return response.data['verificationId'] as String;
    } catch (e) {
      throw Exception('OTP send failed: ${e.toString()}');
    }
  }

  /// Verify OTP code
  Future<UserModel> verifyOtp(String verificationId, String otp) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/verify-otp',
        data: {
          'verificationId': verificationId,
          'otp': otp,
        },
      );

      // Parse response
      final userModel = UserModel.fromJson(response.data);

      // Save token and user data to secure storage
      if (userModel.token != null) {
        await _tokenService.saveToken(userModel.token!);
        await _tokenService.saveUserData(
          userId: userModel.id,
          email: userModel.email,
          name: userModel.displayName ?? '',
        );
      }

      return userModel;
    } catch (e) {
      throw Exception('OTP verification failed: ${e.toString()}');
    }
  }

  /// Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    try {
      final response = await _apiClient.post(
        '/api/auth/google',
      );

      // Parse response
      final userModel = UserModel.fromJson(response.data);

      // Save token and user data to secure storage
      if (userModel.token != null) {
        await _tokenService.saveToken(userModel.token!);
        await _tokenService.saveUserData(
          userId: userModel.id,
          email: userModel.email,
          name: userModel.displayName ?? '',
        );
      }

      return userModel;
    } catch (e) {
      throw Exception('Google sign in failed: ${e.toString()}');
    }
  }
}
