import 'package:hive_flutter/hive_flutter.dart';
import 'package:familysphere_app/features/auth/data/models/user_model.dart';

/// Local Data Source - Hive Operations
/// 
/// This class handles local caching using Hive.
/// Stores user data for offline access.
/// 
/// Why cache locally?
/// - Faster app startup (no network call)
/// - Offline access to user data
/// - Better user experience
class AuthLocalDataSource {
  static const String _userBoxName = 'user_cache';
  static const String _currentUserKey = 'current_user';

  /// Get cached user
  /// 
  /// Returns UserModel if cached, null otherwise
  Future<UserModel?> getCachedUser() async {
    try {
      final box = await Hive.openBox(_userBoxName);
      final userJson = box.get(_currentUserKey);
      
      if (userJson == null) return null;
      
      return UserModel.fromJson(Map<String, dynamic>.from(userJson));
    } catch (e) {
      return null;
    }
  }

  /// Cache user data
  /// 
  /// Stores user in Hive for offline access
  Future<void> cacheUser(UserModel user) async {
    try {
      final box = await Hive.openBox(_userBoxName);
      await box.put(_currentUserKey, user.toJson());
    } catch (e) {
      // Silently fail - caching is not critical
    }
  }

  /// Clear cached user
  /// 
  /// Called on sign out
  Future<void> clearCache() async {
    try {
      final box = await Hive.openBox(_userBoxName);
      await box.delete(_currentUserKey);
    } catch (e) {
      // Silently fail
    }
  }
}
