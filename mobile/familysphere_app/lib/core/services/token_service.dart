import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  final FlutterSecureStorage _secureStorage;
  
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userProfileKey = 'user_profile';
  
  TokenService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();
  
  // Save authentication token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }
  
  // Get stored token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }
  
  // Delete token (logout)
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }
  
  // Save user data
  Future<void> saveUserData({
    required String userId,
    required String email,
    required String name,
    String? userJson,
  }) async {
    final futures = [
      _secureStorage.write(key: _userIdKey, value: userId),
      _secureStorage.write(key: _userEmailKey, value: email),
      _secureStorage.write(key: _userNameKey, value: name),
    ];
    
    if (userJson != null) {
      futures.add(_secureStorage.write(key: _userProfileKey, value: userJson));
    }
    
    await Future.wait(futures);
  }
  
  // Get user data
  Future<Map<String, String?>> getUserData() async {
    final userId = await _secureStorage.read(key: _userIdKey);
    final email = await _secureStorage.read(key: _userEmailKey);
    final name = await _secureStorage.read(key: _userNameKey);
    final userJson = await _secureStorage.read(key: _userProfileKey);
    
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'userJson': userJson,
    };
  }
  
  // Clear all user data (logout)
  Future<void> clearUserData() async {
    await Future.wait([
      _secureStorage.delete(key: _tokenKey),
      _secureStorage.delete(key: _userIdKey),
      _secureStorage.delete(key: _userEmailKey),
      _secureStorage.delete(key: _userNameKey),
      _secureStorage.delete(key: _userProfileKey),
    ]);
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
