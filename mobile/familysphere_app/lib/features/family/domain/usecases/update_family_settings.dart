import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Update Family Settings Use Case
class UpdateFamilySettings {
  final FamilyRepository repository;

  UpdateFamilySettings(this.repository);

  Future<Family> call({
    required String familyId,
    required FamilySettings settings,
    required String requestingUserId,
  }) async {
    return await repository.updateFamilySettings(familyId, settings, requestingUserId);
  }
}
