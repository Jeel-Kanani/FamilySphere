import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Remove Member Use Case
class RemoveMember {
  final FamilyRepository repository;

  RemoveMember(this.repository);

  Future<void> call({
    required String familyId,
    required String userId,
    required String requestingUserId,
  }) async {
    return await repository.removeMember(familyId, userId, requestingUserId);
  }
}
