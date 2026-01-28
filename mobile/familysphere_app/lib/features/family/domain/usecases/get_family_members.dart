import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Get Family Members Use Case
class GetFamilyMembers {
  final FamilyRepository repository;

  GetFamilyMembers(this.repository);

  Future<List<FamilyMember>> call(String familyId) async {
    return await repository.getFamilyMembers(familyId);
  }
}
