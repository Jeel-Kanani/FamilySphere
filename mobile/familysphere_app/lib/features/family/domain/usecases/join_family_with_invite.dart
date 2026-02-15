import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';

class JoinFamilyWithInvite {
  final FamilyRepository repository;

  JoinFamilyWithInvite(this.repository);

  Future<Family> call({String? token, String? code}) async {
    return await repository.joinFamilyWithInvite(token: token, code: code);
  }
}
