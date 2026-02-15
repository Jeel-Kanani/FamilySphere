import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

class ValidateFamilyInvite {
  final FamilyRepository repository;

  ValidateFamilyInvite(this.repository);

  Future<Map<String, dynamic>> call({String? token, String? code}) async {
    return await repository.validateInvite(token: token, code: code);
  }
}
