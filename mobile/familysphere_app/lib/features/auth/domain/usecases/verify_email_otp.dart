import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

class VerifyEmailOtp {
  final AuthRepository _repository;
  VerifyEmailOtp(this._repository);

  Future<void> call({required String email, required String otp}) {
    return _repository.verifyEmailOtp(email: email, otp: otp);
  }
}
