import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Generate Invite Code Use Case
class GenerateInviteCode {
  final FamilyRepository repository;

  GenerateInviteCode(this.repository);

  Future<String> call(String familyId) async {
    return await repository.generateInviteCode(familyId);
  }
}
