import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/entities/family_activity.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';

/// Family Repository Interface
/// 
/// Defines the contract for family data operations
abstract class FamilyRepository {
  /// Create a new family
  /// 
  /// [name] - Name of the family
  /// [userId] - ID of the user creating the family
  /// 
  /// Returns the created Family
  Future<Family> createFamily(String name, String userId);

  /// Join an existing family using invite code
  /// 
  /// [inviteCode] - 6-character invite code
  /// [userId] - ID of the user joining
  /// 
  /// Returns the joined Family
  /// Throws exception if code is invalid
  Future<Family> joinFamily(String inviteCode, String userId);

  /// Get family details by ID
  /// 
  /// [familyId] - ID of the family
  /// 
  /// Returns Family or null if not found
  Future<Family?> getFamily(String familyId);

  /// Get all members of a family
  /// 
  /// [familyId] - ID of the family
  /// 
  /// Returns list of FamilyMember
  Future<List<FamilyMember>> getFamilyMembers(String familyId);

  /// Generate a new invite code for the family
  /// 
  /// [familyId] - ID of the family
  /// 
  /// Returns the new invite code
  Future<String> generateInviteCode(String familyId);

  /// Remove a member from the family
  /// 
  /// [familyId] - ID of the family
  /// [userId] - ID of the user to remove
  /// [requestingUserId] - ID of the user making the request
  /// 
  /// Throws exception if not authorized
  Future<void> removeMember(
    String familyId,
    String userId,
    String requestingUserId,
  );

  /// Update a member's role
  /// 
  /// [familyId] - ID of the family
  /// [userId] - ID of the member
  /// [role] - New role
  /// [requestingUserId] - ID of the user making the request
  Future<void> updateMemberRole(
    String familyId,
    String userId,
    String role,
    String requestingUserId,
  );

  /// Transfer family ownership to another member
  /// 
  /// [familyId] - ID of the family
  /// [userId] - ID of the new owner
  /// [requestingUserId] - ID of current owner
  Future<void> transferOwnership(
    String familyId,
    String userId,
    String requestingUserId,
  );

  /// Leave the family
  /// 
  /// [familyId] - ID of the family
  /// [userId] - ID of the user leaving
  /// 
  /// Throws exception if user is the admin
  Future<void> leaveFamily(String familyId, String userId);

  /// Update family settings
  /// 
  /// [familyId] - ID of the family
  /// [settings] - New settings
  /// [requestingUserId] - ID of the user making the request
  /// 
  /// Returns updated Family
  /// Throws exception if not authorized
  Future<Family> updateFamilySettings(
    String familyId,
    FamilySettings settings,
    String requestingUserId,
  );

  /// Stream of family changes
  /// 
  /// [familyId] - ID of the family to watch
  /// 
  /// Emits Family whenever it changes
  Stream<Family?> watchFamily(String familyId);

  /// Get family activity feed
  Future<List<FamilyActivity>> getFamilyActivity(String familyId);
}
