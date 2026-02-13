import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/entities/family_activity.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/domain/usecases/create_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/join_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/get_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/get_family_members.dart';
import 'package:familysphere_app/features/family/domain/usecases/generate_invite_code.dart';
import 'package:familysphere_app/features/family/domain/usecases/remove_member.dart';
import 'package:familysphere_app/features/family/domain/usecases/leave_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/update_family_settings.dart';
import 'package:familysphere_app/features/family/domain/usecases/update_member_role.dart';
import 'package:familysphere_app/features/family/domain/usecases/transfer_ownership.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/family/data/repositories/family_repository_impl.dart';
import 'package:familysphere_app/features/family/data/datasources/family_remote_datasource.dart';
import 'package:familysphere_app/features/family/data/datasources/family_local_datasource.dart';

// Family Data Sources
final familyRemoteDataSourceProvider = Provider((ref) {
  final apiClient = ref.read(apiClientProvider);
  return FamilyRemoteDataSource(apiClient: apiClient);
});

final familyLocalDataSourceProvider = Provider((ref) {
  return FamilyLocalDataSource();
});

// Family Repository
final familyRepositoryProvider = Provider((ref) {
  return FamilyRepositoryImpl(
    remoteDataSource: ref.read(familyRemoteDataSourceProvider),
    localDataSource: ref.read(familyLocalDataSourceProvider),
  );
});

// Use Cases
final createFamilyUseCaseProvider = Provider((ref) {
  return CreateFamily(ref.read(familyRepositoryProvider));
});

final joinFamilyUseCaseProvider = Provider((ref) {
  return JoinFamily(ref.read(familyRepositoryProvider));
});

final getFamilyUseCaseProvider = Provider((ref) {
  return GetFamily(ref.read(familyRepositoryProvider));
});

final getFamilyMembersUseCaseProvider = Provider((ref) {
  return GetFamilyMembers(ref.read(familyRepositoryProvider));
});

final generateInviteCodeUseCaseProvider = Provider((ref) {
  return GenerateInviteCode(ref.read(familyRepositoryProvider));
});

final removeMemberUseCaseProvider = Provider((ref) {
  return RemoveMember(ref.read(familyRepositoryProvider));
});

final leaveFamilyUseCaseProvider = Provider((ref) {
  return LeaveFamily(ref.read(familyRepositoryProvider));
});

final updateFamilySettingsUseCaseProvider = Provider((ref) {
  return UpdateFamilySettings(ref.read(familyRepositoryProvider));
});

final updateMemberRoleUseCaseProvider = Provider((ref) {
  return UpdateMemberRole(ref.read(familyRepositoryProvider));
});

final transferOwnershipUseCaseProvider = Provider((ref) {
  return TransferOwnership(ref.read(familyRepositoryProvider));
});


// State
class FamilyState {
  final Family? family;
  final List<FamilyMember> members;
  final List<FamilyActivity> activities;
  final bool isLoading;
  final bool isUpdatingSettings;
  final String? error;

  const FamilyState({
    this.family,
    this.members = const [],
    this.activities = const [],
    this.isLoading = false,
    this.isUpdatingSettings = false,
    this.error,
  });

  factory FamilyState.initial() => const FamilyState();

  FamilyState copyWith({
    Family? family,
    List<FamilyMember>? members,
    List<FamilyActivity>? activities,
    bool? isLoading,
    bool? isUpdatingSettings,
    String? error,
  }) {
    return FamilyState(
      family: family ?? this.family,
      members: members ?? this.members,
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      isUpdatingSettings: isUpdatingSettings ?? this.isUpdatingSettings,
      error: error,
    );
  }
}

class FamilyNotifier extends StateNotifier<FamilyState> {
  final Ref _ref;
  final CreateFamily _createFamily;
  final JoinFamily _joinFamily;
  final GetFamily _getFamily;
  final GetFamilyMembers _getFamilyMembers;
  final GenerateInviteCode _generateInviteCode;
  // ignore: unused_field
  final RemoveMember _removeMember;
  final LeaveFamily _leaveFamily;
  final UpdateFamilySettings _updateFamilySettings;
  final UpdateMemberRole _updateMemberRole;
  final TransferOwnership _transferOwnership;
  bool _isLoadingFamily = false;
  DateTime? _lastFamilyLoadAt;

  FamilyNotifier(
    this._ref, {
    required CreateFamily createFamily,
    required JoinFamily joinFamily,
    required GetFamily getFamily,
    required GetFamilyMembers getFamilyMembers,
    required GenerateInviteCode generateInviteCode,
    required RemoveMember removeMember,
    required LeaveFamily leaveFamily,
    required UpdateFamilySettings updateFamilySettings,
    required UpdateMemberRole updateMemberRole,
    required TransferOwnership transferOwnership,
  })  : _createFamily = createFamily,
        _joinFamily = joinFamily,
        _getFamily = getFamily,
        _getFamilyMembers = getFamilyMembers,
        _generateInviteCode = generateInviteCode,
        _removeMember = removeMember,
        _leaveFamily = leaveFamily,
        _updateFamilySettings = updateFamilySettings,
        _updateMemberRole = updateMemberRole,
        _transferOwnership = transferOwnership,
        super(FamilyState.initial());

  Future<void> loadFamily({bool force = false}) async {
    final user = _ref.read(authProvider).user;
    if (user == null || !user.hasFamily) return;
    if (_isLoadingFamily) return;
    if (!force &&
        _lastFamilyLoadAt != null &&
        DateTime.now().difference(_lastFamilyLoadAt!).inSeconds < 20 &&
        (state.family != null || state.members.isNotEmpty)) {
      return;
    }

    _isLoadingFamily = true;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final family = await _getFamily(user.familyId!);
      final members = await _getFamilyMembers(user.familyId!);
      final activities = await _ref.read(familyRepositoryProvider).getFamilyActivity(user.familyId!);
      state = state.copyWith(
        family: family,
        members: members,
        activities: activities,
        isLoading: false,
      );
      _lastFamilyLoadAt = DateTime.now();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _isLoadingFamily = false;
    }
  }

  Future<void> refreshActivity() async {
    final familyId = state.family?.id;
    if (familyId == null) return;
    try {
      final activities = await _ref.read(familyRepositoryProvider).getFamilyActivity(familyId);
      state = state.copyWith(activities: activities);
    } catch (_) {
      // Best-effort refresh
    }
  }

  Future<void> create(String name) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final family = await _createFamily(name, user.id);
      
      // Refresh user to get new family ID
      await _ref.read(authProvider.notifier).refreshUser();
      
      // Load family details
      final members = await _getFamilyMembers(family.id);
      
      state = state.copyWith(
        family: family,
        members: members,
        isLoading: false,
      );
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('User already belongs to a family')) {
        // Recovery: Refresh user and try to load the family they belong to
        await _ref.read(authProvider.notifier).refreshUser();
        final refreshedUser = _ref.read(authProvider).user;
        if (refreshedUser?.familyId != null) {
          await loadFamily();
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: errorStr);
      rethrow;
    }
  }

  Future<void> join(String inviteCode) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final family = await _joinFamily(inviteCode, user.id);
      
      // Refresh user to get new family ID
      await _ref.read(authProvider.notifier).refreshUser();
      
      final members = await _getFamilyMembers(family.id);
      
      state = state.copyWith(
        family: family,
        members: members,
        isLoading: false,
      );
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Already a member')) {
        await _ref.read(authProvider.notifier).refreshUser();
        final refreshedUser = _ref.read(authProvider).user;
        if (refreshedUser?.familyId != null) {
          await loadFamily();
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: errorStr);
      rethrow;
    }
  }

  Future<void> leave() async {
    final user = _ref.read(authProvider).user;
    if (user == null || !user.hasFamily) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _leaveFamily(user.familyId!, user.id);
      
      // Refresh user to clear family ID
      await _ref.read(authProvider.notifier).refreshUser();
      
      state = FamilyState.initial();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow; // Let UI handle it
    }
  }

  // Generate new invite code
  Future<String?> generateNewInviteCode() async {
    final familyId = state.family?.id;
    if (familyId == null) return null;

    try {
      final newCode = await _generateInviteCode(familyId);
      // Update local state
      state = state.copyWith(
        family: state.family?.copyWith(inviteCode: newCode),
      );
      await refreshActivity();
      return newCode;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> updateSettings({
    bool? allowMemberInvites,
    bool? requireApproval,
  }) async {
    final user = _ref.read(authProvider).user;
    final family = state.family;
    if (user == null || family == null) return;

    state = state.copyWith(isUpdatingSettings: true, error: null);
    try {
      final newSettings = family.settings.copyWith(
        allowMemberInvites: allowMemberInvites ?? family.settings.allowMemberInvites,
        requireApproval: requireApproval ?? family.settings.requireApproval,
      );

      final updatedFamily = await _updateFamilySettings(
        familyId: family.id,
        settings: newSettings,
        requestingUserId: user.id,
      );

      state = state.copyWith(
        family: updatedFamily,
        isUpdatingSettings: false,
      );
      await refreshActivity();
    } catch (e) {
      state = state.copyWith(isUpdatingSettings: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> removeMember(String memberId) async {
    final user = _ref.read(authProvider).user;
    final family = state.family;
    if (user == null || family == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _removeMember(
        familyId: family.id,
        userId: memberId,
        requestingUserId: user.id,
      );
      // Refresh members list
      final members = await _getFamilyMembers(family.id);
      state = state.copyWith(
        members: members,
        isLoading: false,
      );
      await refreshActivity();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> changeMemberRole(String memberId, String role) async {
    final user = _ref.read(authProvider).user;
    final family = state.family;
    if (user == null || family == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _updateMemberRole(
        familyId: family.id,
        userId: memberId,
        role: role,
        requestingUserId: user.id,
      );
      // Refresh members list
      final members = await _getFamilyMembers(family.id);
      state = state.copyWith(
        members: members,
        isLoading: false,
      );
      await refreshActivity();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> transferOwnership(String memberId) async {
    final user = _ref.read(authProvider).user;
    final family = state.family;
    if (user == null || family == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _transferOwnership(
        familyId: family.id,
        userId: memberId,
        requestingUserId: user.id,
      );
      // Refresh family + members
      final refreshedFamily = await _getFamily(family.id);
      final members = await _getFamilyMembers(family.id);
      state = state.copyWith(
        family: refreshedFamily ?? family,
        members: members,
        isLoading: false,
      );
      // Refresh user to update role locally
      await _ref.read(authProvider.notifier).refreshUser();
      await refreshActivity();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final familyProvider = StateNotifierProvider<FamilyNotifier, FamilyState>((ref) {
  return FamilyNotifier(
    ref,
    createFamily: ref.read(createFamilyUseCaseProvider),
    joinFamily: ref.read(joinFamilyUseCaseProvider),
    getFamily: ref.read(getFamilyUseCaseProvider),
    getFamilyMembers: ref.read(getFamilyMembersUseCaseProvider),
    generateInviteCode: ref.read(generateInviteCodeUseCaseProvider),
    removeMember: ref.read(removeMemberUseCaseProvider),
    leaveFamily: ref.read(leaveFamilyUseCaseProvider),
    updateFamilySettings: ref.read(updateFamilySettingsUseCaseProvider),
    updateMemberRole: ref.read(updateMemberRoleUseCaseProvider),
    transferOwnership: ref.read(transferOwnershipUseCaseProvider),
  );
});
