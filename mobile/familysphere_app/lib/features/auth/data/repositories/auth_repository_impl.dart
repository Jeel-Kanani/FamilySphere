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
}
