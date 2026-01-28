import 'package:familysphere_app/features/auth/domain/entities/user.dart';
import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

/// Sign In With Google Use Case
/// 
/// Handles Google Sign-In authentication
class SignInWithGoogle {
  final AuthRepository repository;

  SignInWithGoogle(this.repository);

  /// Execute Google Sign-In
  /// 
  /// Returns authenticated User
  /// Throws exception if sign-in fails or is canceled
  Future<User> call() async {
    return await repository.signInWithGoogle();
  }
}
