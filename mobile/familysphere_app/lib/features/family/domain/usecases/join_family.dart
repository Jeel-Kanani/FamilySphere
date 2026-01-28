import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

/// Join Family Use Case
class JoinFamily {
  final FamilyRepository repository;

  JoinFamily(this.repository);

  Future<Family> call(String inviteCode, String userId) async {
    return await repository.joinFamily(inviteCode, userId);
  }
}
