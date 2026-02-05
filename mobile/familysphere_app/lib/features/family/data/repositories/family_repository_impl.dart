import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/entities/family_activity.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/domain/repositories/family_repository.dart';
import 'package:familysphere_app/features/family/data/datasources/family_remote_datasource.dart';
import 'package:familysphere_app/features/family/data/datasources/family_local_datasource.dart';

/// Family Repository Implementation
class FamilyRepositoryImpl implements FamilyRepository {
  final FamilyRemoteDataSource remoteDataSource;
  final FamilyLocalDataSource localDataSource;

  FamilyRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Family> createFamily(String name, String userId) async {
    final family = await remoteDataSource.createFamily(name, userId);
    await localDataSource.cacheFamily(family);
    return family;
  }

  @override
  Future<Family> joinFamily(String inviteCode, String userId) async {
    final family = await remoteDataSource.joinFamily(inviteCode, userId);
    await localDataSource.cacheFamily(family);
    return family;
  }

  @override
  Future<Family?> getFamily(String familyId) async {
    try {
      // Try remote first
      final family = await remoteDataSource.getFamily(familyId);
      if (family != null) {
        await localDataSource.cacheFamily(family);
        return family;
      }
    } catch (e) {
      // Ignore remote errors for now, fall back to cache
      // ignore: avoid_print
      print('Failed to fetch family remotely: $e');
    }

    // Fallback to local
    return await localDataSource.getCachedFamily();
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers(String familyId) async {
    try {
      final members = await remoteDataSource.getFamilyMembers(familyId);
      await localDataSource.cacheFamilyMembers(familyId, members);
      return members;
    } catch (e) {
      // ignore: avoid_print
      print('Failed to fetch members remotely: $e');
      return await localDataSource.getCachedFamilyMembers(familyId);
    }
  }

  @override
  Future<String> generateInviteCode(String familyId) async {
    return await remoteDataSource.generateInviteCode(familyId);
  }

  @override
  Future<void> removeMember(String familyId, String userId, String requestingUserId) async {
    final family = await getFamily(familyId);
    if (family == null) throw Exception('Family not found');

    if (!family.canRemoveMember(requestingUserId, userId)) {
      throw Exception('Not authorized to remove member');
    }

    await remoteDataSource.removeMember(familyId, userId);
  }

  @override
  Future<void> updateMemberRole(
    String familyId,
    String userId,
    String role,
    String requestingUserId,
  ) async {
    final family = await getFamily(familyId);
    if (family == null) throw Exception('Family not found');

    if (!family.isAdmin(requestingUserId)) {
      throw Exception('Not authorized to update roles');
    }

    await remoteDataSource.updateMemberRole(familyId, userId, role);
  }

  @override
  Future<void> transferOwnership(
    String familyId,
    String userId,
    String requestingUserId,
  ) async {
    final family = await getFamily(familyId);
    if (family == null) throw Exception('Family not found');

    if (!family.isAdmin(requestingUserId) || family.createdBy != requestingUserId) {
      throw Exception('Only the creator can transfer ownership');
    }

    await remoteDataSource.transferOwnership(familyId, userId);
  }

  @override
  Future<void> leaveFamily(String familyId, String userId) async {
    final family = await getFamily(familyId);
    if (family == null) return; // Already gone or error

    if (family.isAdmin(userId) && family.memberCount > 1) {
      throw Exception('Admin cannot leave. Transfer ownership or remove all members first.');
      // NOTE: Simplification for MVP. Ideally transfer ownership logic exists.
    }

    await remoteDataSource.leaveFamily(familyId, userId);
    await localDataSource.clearCache();
  }

  @override
  Future<Family> updateFamilySettings(
    String familyId, 
    FamilySettings settings, 
    String requestingUserId,
  ) async {
    final family = await getFamily(familyId);
    if (family == null) throw Exception('Family not found');

    if (!family.isAdmin(requestingUserId)) {
      throw Exception('Not authorized to update settings');
    }
    
    final updatedFamily = await remoteDataSource.updateFamilySettings(familyId, settings);
    await localDataSource.cacheFamily(updatedFamily);
    return updatedFamily;
  }

  @override
  Stream<Family?> watchFamily(String familyId) {
    return remoteDataSource.watchFamily(familyId);
  }

  @override
  Future<List<FamilyActivity>> getFamilyActivity(String familyId) async {
    return remoteDataSource.getFamilyActivity(familyId);
  }
}
