import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Transfer family ownership
class TransferOwnership {
  final FamilyRepository repository;

  TransferOwnership(this.repository);

  Future<void> call({
    required String familyId,
    required String userId,
    required String requestingUserId,
  }) async {
    return repository.transferOwnership(familyId, userId, requestingUserId);
  }
}
