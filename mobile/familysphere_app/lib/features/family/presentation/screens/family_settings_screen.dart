import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

class FamilySettingsScreen extends ConsumerStatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  ConsumerState<FamilySettingsScreen> createState() =>
      _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends ConsumerState<FamilySettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyProvider.notifier).loadFamily(force: true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final family = familyState.family;
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (family != null && _nameController.text != family.name) {
      _nameController.text = family.name;
    }

    if (familyState.isLoading && family == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (family == null || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Settings')),
        body: const Center(child: Text('Family details are unavailable.')),
      );
    }

    final isAdmin = user.isAdmin;
    final members = familyState.members;
    final currentUserId = user.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildFamilyProfileCard(
            context,
            family,
            familyState.isUpdatingSettings,
            isAdmin,
          ),
          const SizedBox(height: 20),
          _buildPermissionsCard(
            context,
            family,
            familyState.isUpdatingSettings,
            isAdmin,
          ),
          const SizedBox(height: 20),
          _buildInviteCard(context, family, isAdmin),
          const SizedBox(height: 20),
          _buildMemberManagementCard(
            context,
            members,
            currentUserId,
            family,
            isAdmin,
            isDark,
          ),
          const SizedBox(height: 20),
          _buildDangerZone(
            context,
            members,
            currentUserId,
            family,
            isAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyProfileCard(
    BuildContext context,
    Family family,
    bool isBusy,
    bool isAdmin,
  ) {
    return _SettingsSection(
      title: 'Family Profile',
      subtitle: 'Update the family name your members see across the app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            readOnly: !isAdmin || isBusy,
            decoration: InputDecoration(
              labelText: 'Family name',
              hintText: 'Enter family name',
              helperText: isAdmin
                  ? 'Admins can rename the family.'
                  : 'Only admins can rename the family.',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: (!isAdmin || isBusy) ? null : _saveFamilyName,
              child: isBusy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Name'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(
    BuildContext context,
    Family family,
    bool isBusy,
    bool isAdmin,
  ) {
    return _SettingsSection(
      title: 'Permissions',
      subtitle: 'Control who can invite new members and whether joining needs approval.',
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow member invites'),
            subtitle: const Text(
              'Members can create invites in addition to admins.',
            ),
            value: family.settings.allowMemberInvites,
            onChanged: (!isAdmin || isBusy)
                ? null
                : (value) => _updateSettings(allowMemberInvites: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require approval'),
            subtitle: const Text(
              'Keep invite approvals tighter for private families.',
            ),
            value: family.settings.requireApproval,
            onChanged: (!isAdmin || isBusy)
                ? null
                : (value) => _updateSettings(requireApproval: value),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context, Family family, bool isAdmin) {
    return _SettingsSection(
      title: 'Invite Access',
      subtitle: 'Share the current invite code or regenerate it for tighter control.',
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Invite Code',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    family.inviteCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isAdmin ? _regenerateInviteCode : null,
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberManagementCard(
    BuildContext context,
    List<FamilyMember> members,
    String currentUserId,
    Family family,
    bool isAdmin,
    bool isDark,
  ) {
    return _SettingsSection(
      title: 'Member Roles',
      subtitle: 'Promote admins, set read-only viewers, or transfer ownership.',
      child: Column(
        children: members.map((member) {
          final isSelf = member.userId == currentUserId;
          final isOwner = family.createdBy == member.userId;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: member.photoUrl != null &&
                          member.photoUrl!.isNotEmpty
                      ? NetworkImage(member.photoUrl!)
                      : null,
                  child: member.photoUrl == null || member.photoUrl!.isEmpty
                      ? Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSelf
                            ? '${member.displayName} (You)'
                            : member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? 'Owner | ${_roleLabel(member.role)}'
                            : _roleLabel(member.role),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: isAdmin && !isSelf,
                  onSelected: (value) => _handleMemberMenuAction(
                    member: member,
                    action: value,
                    isOwner: isOwner,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'viewer',
                      child: Text('Set as Viewer'),
                    ),
                    const PopupMenuItem(
                      value: 'member',
                      child: Text('Set as Member'),
                    ),
                    const PopupMenuItem(
                      value: 'admin',
                      child: Text('Set as Admin'),
                    ),
                    if (!isOwner)
                      const PopupMenuItem(
                        value: 'transfer',
                        child: Text('Transfer Ownership'),
                      ),
                    if (!isOwner)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text(
                          'Remove Member',
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDangerZone(
    BuildContext context,
    List<FamilyMember> members,
    String currentUserId,
    Family family,
    bool isAdmin,
  ) {
    final canLeaveDirectly = !isAdmin || members.length <= 1;

    return _SettingsSection(
      title: 'Danger Zone',
      subtitle: 'Use these actions carefully because they affect the whole family.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canLeaveDirectly
                ? 'You can leave this family now.'
                : 'Transfer ownership or remove all other members before leaving.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: canLeaveDirectly ? _leaveFamily : null,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Leave Family'),
          ),
        ],
      ),
    );
  }

  String _roleLabel(FamilyRole role) {
    switch (role) {
      case FamilyRole.admin:
        return 'Admin';
      case FamilyRole.viewer:
        return 'Viewer';
      case FamilyRole.member:
        return 'Member';
    }
  }

  Future<void> _saveFamilyName() async {
    final nextName = _nameController.text.trim();
    if (nextName.isEmpty) {
      _showMessage('Please enter a family name.', isError: true);
      return;
    }

    try {
      await ref.read(familyProvider.notifier).updateFamilyName(nextName);
      _showMessage('Family name updated.');
    } catch (e) {
      _showMessage('Failed to update family name: $e', isError: true);
    }
  }

  Future<void> _updateSettings({
    bool? allowMemberInvites,
    bool? requireApproval,
  }) async {
    try {
      await ref.read(familyProvider.notifier).updateSettings(
            allowMemberInvites: allowMemberInvites,
            requireApproval: requireApproval,
          );
      _showMessage('Family settings updated.');
    } catch (e) {
      _showMessage('Failed to update family settings: $e', isError: true);
    }
  }

  Future<void> _regenerateInviteCode() async {
    try {
      final code =
          await ref.read(familyProvider.notifier).generateNewInviteCode();
      if (code != null) {
        _showMessage('Invite code regenerated: $code');
      }
    } catch (e) {
      _showMessage('Failed to regenerate invite code: $e', isError: true);
    }
  }

  Future<void> _handleMemberMenuAction({
    required FamilyMember member,
    required String action,
    required bool isOwner,
  }) async {
    if (action == 'remove') {
      final confirmed = await _confirm(
        title: 'Remove member?',
        message:
            'Remove ${member.displayName} from the family? They will lose access immediately.',
      );
      if (confirmed == true) {
        try {
          await ref.read(familyProvider.notifier).removeMember(member.userId);
          _showMessage('${member.displayName} removed.');
        } catch (e) {
          _showMessage('Failed to remove member: $e', isError: true);
        }
      }
      return;
    }

    if (action == 'transfer') {
      final confirmed = await _confirm(
        title: 'Transfer ownership?',
        message:
            'Transfer family ownership to ${member.displayName}? You will remain in the family as a member.',
      );
      if (confirmed == true) {
        try {
          await ref.read(familyProvider.notifier).transferOwnership(member.userId);
          _showMessage('Ownership transferred to ${member.displayName}.');
        } catch (e) {
          _showMessage('Failed to transfer ownership: $e', isError: true);
        }
      }
      return;
    }

    if (isOwner) {
      _showMessage('Owner role cannot be changed directly.', isError: true);
      return;
    }

    try {
      await ref.read(familyProvider.notifier).changeMemberRole(
            member.userId,
            action,
          );
      _showMessage('${member.displayName} is now ${action.toUpperCase()}.');
    } catch (e) {
      _showMessage('Failed to update role: $e', isError: true);
    }
  }

  Future<void> _leaveFamily() async {
    final confirmed = await _confirm(
      title: 'Leave family?',
      message: 'You will lose access to this family\'s shared spaces.',
    );
    if (confirmed != true) return;

    try {
      await ref.read(familyProvider.notifier).leave();
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
      _showMessage('You left the family.');
    } catch (e) {
      _showMessage('Failed to leave family: $e', isError: true);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : null,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
