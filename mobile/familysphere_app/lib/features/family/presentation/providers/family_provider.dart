import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/domain/usecases/create_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/join_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/get_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/get_family_members.dart';
import 'package:familysphere_app/features/family/domain/usecases/generate_invite_code.dart';
import 'package:familysphere_app/features/family/domain/usecases/remove_member.dart';
import 'package:familysphere_app/features/family/domain/usecases/leave_family.dart';
import 'package:familysphere_app/features/family/domain/usecases/update_family_settings.dart';
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


// State
class FamilyState {
  final Family? family;
  final List<FamilyMember> members;
  final bool isLoading;
  final String? error;

  const FamilyState({
    this.family,
    this.members = const [],
    this.isLoading = false,
    this.error,
  });

  factory FamilyState.initial() => const FamilyState();

  FamilyState copyWith({
    Family? family,
    List<FamilyMember>? members,
    bool? isLoading,
    String? error,
  }) {
    return FamilyState(
      family: family ?? this.family,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
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
  })  : _createFamily = createFamily,
        _joinFamily = joinFamily,
        _getFamily = getFamily,
        _getFamilyMembers = getFamilyMembers,
        _generateInviteCode = generateInviteCode,
        _removeMember = removeMember,
        _leaveFamily = leaveFamily,
        super(FamilyState.initial());

  Future<void> loadFamily() async {
    final user = _ref.read(authProvider).user;
    if (user == null || !user.hasFamily) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final family = await _getFamily(user.familyId!);
      final members = await _getFamilyMembers(user.familyId!);
      state = state.copyWith(
        family: family,
        members: members,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      return newCode;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
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
  );
});
