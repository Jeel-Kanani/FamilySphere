import 'package:familysphere_app/features/auth/domain/repositories/auth_repository.dart';

class SendEmailOtp {
  final AuthRepository _repository;
  SendEmailOtp(this._repository);

  Future<void> call({required String email}) {
    return _repository.sendEmailOtp(email: email);
  }
}
