import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Update member role use case
class UpdateMemberRole {
  final FamilyRepository repository;

  UpdateMemberRole(this.repository);

  Future<void> call({
    required String familyId,
    required String userId,
    required String role,
    required String requestingUserId,
  }) async {
    return repository.updateMemberRole(familyId, userId, role, requestingUserId);
  }
}
