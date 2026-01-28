import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:familysphere_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:familysphere_app/features/auth/data/datasources/auth_local_datasource.dart';

/// Authentication Repository Implementation
/// 
/// This class implements the AuthRepository interface.
/// It coordinates between remote (Firebase) and local (Hive) data sources.
/// 
/// Strategy:
/// 1. Try remote first (Firebase)
/// 2. Cache locally (Hive) for offline access
/// 3. Fall back to cache if offline
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<String> sendOtp(String phoneNumber) async {
    // Send OTP via Firebase
    // No caching needed for verification ID
    return await remoteDataSource.sendOtp(phoneNumber);
  }

  @override
  Future<User> verifyOtp(String verificationId, String otpCode) async {
    // Verify OTP with Firebase
    final user = await remoteDataSource.verifyOtp(verificationId, otpCode);
    
    // Cache user locally for offline access
    await localDataSource.cacheUser(user);
    
    return user;
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      // Try to get from Firebase first (ensures fresh data)
      final user = await remoteDataSource.getCurrentUser();
      
      if (user != null) {
        // Cache for offline access
        await localDataSource.cacheUser(user);
        return user;
      }
      
      // If not in Firebase, try local cache (offline mode)
      return await localDataSource.getCachedUser();
    } catch (e) {
      // Network error - fall back to cache
      return await localDataSource.getCachedUser();
    }
  }

  @override
  Future<User> updateProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {
    // Update in Firebase
    final updatedUser = await remoteDataSource.updateProfile(
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl,
    );
    
    // Update cache
    await localDataSource.cacheUser(updatedUser);
    
    return updatedUser;
  }

  @override
  Future<void> signOut() async {
    // Sign out from Firebase and Google
    await remoteDataSource.signOut();
    
    // Clear local cache
    await localDataSource.clearCache();
  }

  @override
  Future<User> signInWithGoogle() async {
    // Sign in with Google via Firebase
    final user = await remoteDataSource.signInWithGoogle();
    
    // Cache user locally
    await localDataSource.cacheUser(user);
    
    return user;
  }

  @override
  Stream<User?> get authStateChanges {
    // Stream from Firebase
    // We could enhance this to merge with local cache
    return remoteDataSource.authStateChanges;
  }
}
