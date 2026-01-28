import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Leave Family Use Case
class LeaveFamily {
  final FamilyRepository repository;

  LeaveFamily(this.repository);

  Future<void> call(String familyId, String userId) async {
    return await repository.leaveFamily(familyId, userId);
  }
}
