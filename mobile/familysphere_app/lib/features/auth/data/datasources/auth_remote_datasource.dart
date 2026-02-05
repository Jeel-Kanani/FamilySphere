import 'dart:convert';
import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/core/config/api_config.dart';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/core/services/token_service.dart';
import 'package:familysphere_app/features/auth/data/models/user_model.dart';
import 'package:familysphere_app/core/config/google_auth_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:familysphere_app/features/auth/data/models/login_request.dart';
import 'package:familysphere_app/features/auth/data/models/register_request.dart';
import 'package:flutter/foundation.dart';

class AuthRemoteDataSource {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  AuthRemoteDataSource({
    required ApiClient apiClient,
    required TokenService tokenService,
  })  : _apiClient = apiClient,
        _tokenService = tokenService;

  /// Send email OTP for registration
  Future<void> sendEmailOtp(String email) async {
    try {
      await _apiClient.post(
        ApiConfig.sendEmailOtpEndpoint,
        data: {'email': email},
      );
    } catch (e) {
      throw Exception('OTP send failed: ${e.toString()}');
    }
  }

  /// Verify email OTP for registration
  Future<void> verifyEmailOtp(String email, String otp) async {
    try {
      await _apiClient.post(
        ApiConfig.verifyEmailOtpEndpoint,
        data: {'email': email, 'otp': otp},
      );
    } catch (e) {
      throw Exception('OTP verification failed: ${e.toString()}');
    }
  }

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
          userJson: userModel.toJsonString(),
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
          userJson: userModel.toJsonString(),
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
      // 1. Check if token exists
      final isLoggedIn = await _tokenService.isLoggedIn();
      if (!isLoggedIn) {
        return null;
      }

      try {
        // 2. Attempt to fetch current user from backend
        // ignore: avoid_print
        print('AuthRemoteDataSource: Fetching user from backend...');
        final response = await _apiClient.get(ApiConfig.currentUserEndpoint);

        // 3. Parse and cache the fresh user data
        final userModel = UserModel.fromJson(response.data);
        await _tokenService.saveUserData(
          userId: userModel.id,
          email: userModel.email,
          name: userModel.displayName ?? userModel.email,
          userJson: userModel.toJsonString(),
        );
        return userModel;
      } catch (e) {
        // 4. If backend call fails (network error), try to return cached user data
        // ignore: avoid_print
        print('AuthRemoteDataSource: Backend fetch failed: $e');
        
        // If it's an authentication error (401/403), we SHOULD NOT use cache
        if (e.toString().contains('401') || e.toString().contains('403')) {
          // ignore: avoid_print
          print('AuthRemoteDataSource: Auth error, clearing session');
          await _tokenService.clearUserData();
          return null;
        }

        // For other errors (offline, timeout), check local cache
        // ignore: avoid_print
        print('AuthRemoteDataSource: Attempting to use cached user data');
        final userData = await _tokenService.getUserData();
        final userJson = userData['userJson'];
        
        if (userJson != null) {
          try {
            // Reconstruct UserModel from cached JSON
            final Map<String, dynamic> decoded = json.decode(userJson);
            return UserModel.fromJson(decoded);
          } catch (cacheError) {
             // ignore: avoid_print
            print('AuthRemoteDataSource: Failed to parse cached user JSON: $cacheError');
          }
        }
        
        // Secondary Fallback: Try to use individual stored fields (for older sessions)
        final userId = userData['userId'];
        final email = userData['email'];
        final name = userData['name'];
        
        if (userId != null && email != null) {
          // ignore: avoid_print
          print('AuthRemoteDataSource: Reconstructing partial user from stored fields');
          return UserModel(
            id: userId,
            email: email,
            displayName: name ?? email,
            role: UserRole.member, // Default to member if unknown
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
        
        // No cache available and backend failed
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      print('AuthRemoteDataSource: Error in getCurrentUser logic: $e');
      return null;
    }
  }

  Future<UserModel?> getLocalUser() async {
    try {
      final isLoggedIn = await _tokenService.isLoggedIn();
      if (!isLoggedIn) return null;

      final userData = await _tokenService.getUserData();
      final userJson = userData['userJson'];

      if (userJson != null) {
        final Map<String, dynamic> decoded = json.decode(userJson);
        return UserModel.fromJson(decoded);
      }

      final userId = userData['userId'];
      final email = userData['email'];
      final name = userData['name'];

      if (userId != null && email != null) {
        return UserModel(
          id: userId,
          email: email,
          displayName: name ?? email,
          role: UserRole.member,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('AuthRemoteDataSource: Error getting local user: $e');
      return null;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      // Best-effort server logout (token revocation)
      try {
        await _apiClient.post(ApiConfig.logoutEndpoint);
      } catch (_) {
        // Ignore network/server errors and still clear local session
      }

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
        userJson: userModel.toJsonString(),
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
          userJson: userModel.toJsonString(),
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
      if (GoogleAuthConfig.webClientId.isEmpty) {
        throw Exception('Google sign-in is not configured. Add Web Client ID.');
      }

      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: kIsWeb ? GoogleAuthConfig.webClientId : null,
        serverClientId: kIsWeb ? null : GoogleAuthConfig.webClientId,
      );

      // Force account chooser by clearing any previous Google session
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        throw Exception('Google sign-in cancelled');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Failed to retrieve Google ID token');
      }

      final response = await _apiClient.post(
        '/api/auth/google',
        data: {
          'idToken': idToken,
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
          userJson: userModel.toJsonString(),
        );
      }

      return userModel;
    } catch (e) {
      throw Exception('Google sign in failed: ${e.toString()}');
    }
  }
}
