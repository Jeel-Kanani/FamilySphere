import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

/// Get Local User Use Case
/// 
/// Business Rule: Retrieve the user from local cache for instant UI response
class GetLocalUser {
  final AuthRepository repository;

  GetLocalUser(this.repository);

  Future<User?> call() async {
    return await repository.getLocalUser();
  }
}
