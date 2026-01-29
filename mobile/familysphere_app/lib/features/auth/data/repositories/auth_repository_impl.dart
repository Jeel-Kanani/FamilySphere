import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:familysphere_app/features/auth/data/datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.register(name, email, password);
  }

  @override
  Future<User> login({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.login(email, password);
  }

  @override
  Future<User?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<String> sendOtp({required String phoneNumber}) async {
    return await remoteDataSource.sendOtp(phoneNumber);
  }

  @override
  Future<User> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    return await remoteDataSource.verifyOtp(verificationId, otp);
  }

  @override
  Future<User> signInWithGoogle() async {
    return await remoteDataSource.signInWithGoogle();
  }

  @override
  Future<User> updateProfile({
    required String name,
    String? email,
    String? photoUrl,
  }) async {
    return await remoteDataSource.updateProfile(name, email, photoUrl);
  }
}
