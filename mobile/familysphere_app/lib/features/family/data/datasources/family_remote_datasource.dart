import 'dart:math';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/features/family/data/models/family_model.dart';
import 'package:familysphere_app/features/family/data/models/family_member_model.dart';
import 'package:familysphere_app/features/family/domain/entities/family_activity.dart';
import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/entities/family_invite.dart';

/// Remote Data Source - Backend API Operations
class FamilyRemoteDataSource {
  final ApiClient _apiClient;

  FamilyRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Create a new family
  Future<FamilyModel> createFamily(String name, String userId) async {
    final inviteCode = _generateInviteCode();
    
    final response = await _apiClient.post(
      '/api/families',
      data: {
        'name': name,
        'inviteCode': inviteCode,
      },
    );

    return FamilyModel.fromJson(response.data);
  }

  /// Join a family using invite code
  Future<FamilyModel> joinFamily(String inviteCode, String userId) async {
    final response = await _apiClient.post(
      '/api/families/join',
      data: {
        'inviteCode': inviteCode,
      },
    );

    return FamilyModel.fromJson(response.data);
  }

  /// Get family by ID
  Future<FamilyModel?> getFamily(String familyId) async {
    try {
      final response = await _apiClient.get('/api/families/$familyId');
      return FamilyModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// Get all family members with their details
  Future<List<FamilyMemberModel>> getFamilyMembers(String familyId) async {
    final response = await _apiClient.get('/api/families/$familyId/members');
    
    final List<dynamic> membersList = response.data['members'] ?? [];
    return membersList.map((json) => FamilyMemberModel.fromJson(json)).toList();
  }

  /// Generate a new invite code
  Future<String> generateInviteCode(String familyId) async {
    final newCode = _generateInviteCode();
    await _apiClient.put(
      '/api/families/$familyId/invite-code',
      data: {
        'inviteCode': newCode,
      },
    );
    return newCode;
  }

  /// Remove member
  Future<void> removeMember(String familyId, String userId) async {
    await _apiClient.delete(
      '/api/families/$familyId/members/$userId',
    );
  }

  /// Update member role
  Future<void> updateMemberRole(String familyId, String userId, String role) async {
    await _apiClient.put(
      '/api/families/$familyId/members/$userId/role',
      data: {'role': role},
    );
  }

  /// Transfer ownership
  Future<void> transferOwnership(String familyId, String userId) async {
    await _apiClient.post(
      '/api/families/$familyId/members/$userId/transfer-ownership',
    );
  }

  /// Leave family
  Future<void> leaveFamily(String familyId, String userId) async {
    await _apiClient.post(
      '/api/families/$familyId/leave',
    );
  }

  /// Update family settings
  Future<FamilyModel> updateFamilySettings(String familyId, FamilySettings settings) async {
    final response = await _apiClient.put(
      '/api/families/$familyId/settings',
      data: {
        'allowMemberInvites': settings.allowMemberInvites,
        'requireApproval': settings.requireApproval,
      },
    );

    return FamilyModel.fromJson(response.data);
  }

  /// Stream family changes
  /// Note: Streaming not supported with REST API, will need polling or WebSocket
  /// For now, this is a placeholder that throws an error
  Stream<FamilyModel?> watchFamily(String familyId) {
    throw UnimplementedError('Real-time streaming not implemented with REST API');
  }

  /// Get family activity feed
  Future<List<FamilyActivity>> getFamilyActivity(String familyId) async {
    final response = await _apiClient.get('/api/families/$familyId/activity');
    final List<dynamic> activities = response.data['activities'] ?? [];
    return activities.map((json) {
      final createdAt = json['createdAt'] as String?;
      return FamilyActivity(
        id: json['_id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'unknown',
        message: json['message']?.toString() ?? '',
        actorName: json['actorName']?.toString(),
        createdAt: createdAt != null ? DateTime.parse(createdAt) : DateTime.now(),
      );
    }).toList();
  }

  /// Create a new secure invite
  Future<FamilyInvite> createInvite(String familyId, String type) async {
    final response = await _apiClient.post(
      '/api/families/$familyId/invites',
      data: {'type': type},
    );
    return FamilyInvite.fromJson(response.data);
  }

  /// Validate an invite
  Future<Map<String, dynamic>> validateInvite({String? token, String? code}) async {
    final response = await _apiClient.get(
      '/api/families/invites/validate',
      queryParameters: {
        if (token != null) 'token': token,
        if (code != null) 'code': code,
      },
    );
    return response.data;
  }

  /// Join family with invite
  Future<FamilyModel> joinWithInvite({String? token, String? code}) async {
    final response = await _apiClient.post(
      '/api/families/join-invite',
      data: {
        if (token != null) 'token': token,
        if (code != null) 'code': code,
      },
    );
    return FamilyModel.fromJson(response.data);
  }

  /// Generate 6-char random alphanumeric code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded confusing chars like I, 1, O, 0
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      6,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }
}
