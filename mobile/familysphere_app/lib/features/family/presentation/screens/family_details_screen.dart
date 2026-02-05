import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/domain/entities/family_activity.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class FamilyDetailsScreen extends ConsumerStatefulWidget {
  const FamilyDetailsScreen({super.key});

  @override
  ConsumerState<FamilyDetailsScreen> createState() => _FamilyDetailsScreenState();
}

class _FamilyDetailsScreenState extends ConsumerState<FamilyDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Load family data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyProvider.notifier).loadFamily();
    });
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final currentUser = ref.watch(authProvider).user;
    final family = familyState.family;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (familyState.isLoading && family == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (family == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No family info found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(familyProvider.notifier).loadFamily();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final isAdmin = family.isAdmin(currentUser?.id ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Settings'),
        centerTitle: true,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Navigator.pushNamed(context, '/invite-member');
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(familyProvider.notifier).loadFamily(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Family Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      family.name.isNotEmpty ? family.name[0].toUpperCase() : 'F',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    family.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created ${DateFormat.yMMMd().format(family.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
            
              const SizedBox(height: 32),

            // Family Controls
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Family Controls',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.qr_code_rounded, color: AppTheme.primaryColor),
                    title: const Text('Invite Code'),
                    subtitle: Text(
                      family.inviteCode,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            tooltip: 'Copy code',
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryColor),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: family.inviteCode));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invite code copied')),
                              );
                              }
                            },
                          ),
                        IconButton(
                          tooltip: 'Regenerate code',
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                          onPressed: isAdmin
                              ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Regenerate invite code?'),
                                        content: const Text(
                                          'Old invite links will stop working. Share the new code with your family.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Regenerate'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm != true) return;

                                    final newCode = await ref.read(familyProvider.notifier).generateNewInviteCode();
                                    if (context.mounted && newCode != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('New invite code generated')),
                                      );
                                    }
                                  }
                              : null,
                        ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.group_add_rounded, color: AppTheme.primaryColor),
                      title: const Text('Allow Member Invites'),
                      subtitle: const Text('Let members invite others to the family'),
                      value: family.settings.allowMemberInvites,
                      onChanged: isAdmin && !familyState.isUpdatingSettings
                          ? (value) async {
                              try {
                                await ref.read(familyProvider.notifier).updateSettings(
                                      allowMemberInvites: value,
                                    );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update: $e')),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.verified_user_rounded, color: AppTheme.primaryColor),
                      title: const Text('Require Approval'),
                      subtitle: const Text('New members need admin approval'),
                      value: family.settings.requireApproval,
                      onChanged: isAdmin && !familyState.isUpdatingSettings
                          ? (value) async {
                              try {
                                await ref.read(familyProvider.notifier).updateSettings(
                                      requireApproval: value,
                                    );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update: $e')),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                    if (familyState.isUpdatingSettings)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

            // Members Section
              Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Members (${familyState.members.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/invite-member');
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Invite'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: familyState.members.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = familyState.members[index];
                  final isMe = member.userId == currentUser?.id;
                  final isCreator = member.userId == family.createdBy;
                  final isCurrentUserCreator = currentUser?.id == family.createdBy;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: member.photoUrl != null 
                          ? NetworkImage(member.photoUrl!) 
                          : null,
                      child: member.photoUrl == null
                          ? Text(
                              member.displayName.isNotEmpty 
                                  ? member.displayName[0].toUpperCase() 
                                  : '?',
                              style: const TextStyle(color: Colors.grey),
                            )
                          : null,
                    ),
                    title: Text(
                      isMe ? '${member.displayName} (You)' : member.displayName,
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(member.role.displayName),
                    trailing: isAdmin && !isMe
                        ? (isCreator
                            ? const Icon(Icons.lock_rounded, color: Colors.grey)
                            : PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'remove') {
                                    await _confirmRemoveMember(context, ref, member.displayName, member.userId);
                                  } else if (value == 'make_admin') {
                                    await _confirmRoleChange(context, ref, member.displayName, member.userId, 'admin');
                                  } else if (value == 'make_member') {
                                    await _confirmRoleChange(context, ref, member.displayName, member.userId, 'member');
                                  } else if (value == 'transfer') {
                                    await _confirmTransferOwnership(context, ref, member.displayName, member.userId);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (isCurrentUserCreator)
                                    const PopupMenuItem(
                                      value: 'transfer',
                                      child: Text('Transfer Ownership'),
                                    ),
                                  if (member.role != FamilyRole.admin)
                                    const PopupMenuItem(
                                      value: 'make_admin',
                                      child: Text('Make Admin'),
                                    ),
                                  if (member.role != FamilyRole.member)
                                    const PopupMenuItem(
                                      value: 'make_member',
                                      child: Text('Make Member'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove Member'),
                                  ),
                                ],
                                child: const Icon(Icons.more_vert),
                              ))
                        : null,
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),

            // Activity Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => ref.read(familyProvider.notifier).refreshActivity(),
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: familyState.activities.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No recent activity yet.'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: familyState.activities.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final activity = familyState.activities[index];
                        final time = DateFormat('MMM d, h:mm a').format(activity.createdAt);
                        return ListTile(
                          leading: _activityIcon(activity),
                          title: Text(activity.message),
                          subtitle: Text('${activity.actorName ?? 'System'} • $time'),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 32),
            
            // Danger Zone
            Text(
              'Danger Zone',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text('Leave Family', style: TextStyle(color: Colors.red)),
                    subtitle: const Text('You will need an invite to rejoin'),
                    onTap: () => _confirmLeaveFamily(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeaveFamily(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Family?'),
        content: const Text(
          'Are you sure you want to leave this family? You will lose access to all shared content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(familyProvider.notifier).leave();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/family-setup');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to leave family: $e')),
                  );
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _activityIcon(FamilyActivity activity) {
    switch (activity.type) {
      case 'family_created':
        return const Icon(Icons.family_restroom_rounded, color: AppTheme.primaryColor);
      case 'member_joined':
        return const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.successColor);
      case 'member_left':
        return const Icon(Icons.exit_to_app_rounded, color: AppTheme.warningColor);
      case 'member_removed':
        return const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor);
      case 'role_changed':
        return const Icon(Icons.security_rounded, color: AppTheme.primaryColor);
      case 'ownership_transferred':
        return const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryColor);
      case 'invite_regenerated':
        return const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor);
      case 'settings_updated':
        return const Icon(Icons.tune_rounded, color: AppTheme.primaryColor);
      default:
        return const Icon(Icons.info_outline, color: AppTheme.textSecondary);
    }
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    String name,
    String userId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove $name from the family?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(familyProvider.notifier).removeMember(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  Future<void> _confirmRoleChange(
    BuildContext context,
    WidgetRef ref,
    String name,
    String userId,
    String role,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change role?'),
        content: Text('Change $name to ${role == 'admin' ? 'Admin' : 'Member'}?'),
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

    if (confirm != true) return;

    try {
      await ref.read(familyProvider.notifier).changeMemberRole(userId, role);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: $e')),
        );
      }
    }
  }

  Future<void> _confirmTransferOwnership(
    BuildContext context,
    WidgetRef ref,
    String name,
    String userId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer ownership?'),
        content: Text('Make $name the new owner? You will become a member.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(familyProvider.notifier).transferOwnership(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ownership transferred')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to transfer: $e')),
        );
      }
    }
  }
}
