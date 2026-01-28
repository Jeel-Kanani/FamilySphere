import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Create Family Use Case
class CreateFamily {
  final FamilyRepository repository;

  CreateFamily(this.repository);

  Future<Family> call(String name, String userId) async {
    return await repository.createFamily(name, userId);
  }
}
