import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Get Family Use Case
class GetFamily {
  final FamilyRepository repository;

  GetFamily(this.repository);

  Future<Family?> call(String familyId) async {
    return await repository.getFamily(familyId);
  }
}
