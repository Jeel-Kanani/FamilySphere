import 'package:familysphere_app/features/family/domain/entities/family_invite.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

class CreateFamilyInvite {
  final FamilyRepository repository;

  CreateFamilyInvite(this.repository);

  Future<FamilyInvite> call(String familyId, String type, {String targetRole = 'member'}) async {
    return await repository.createInvite(familyId, type, targetRole: targetRole);
  }
}
