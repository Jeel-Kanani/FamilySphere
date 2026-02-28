import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

class SendEmailOtp {
  final AuthRepository _repository;
  SendEmailOtp(this._repository);

  /// Returns the dev OTP code when the server exposes it (non-production mode).
  Future<String?> call({required String email}) {
    return _repository.sendEmailOtp(email: email);
  }
}
