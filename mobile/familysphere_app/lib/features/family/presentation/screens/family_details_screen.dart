import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/domain/entities/family.dart' as family_entity;
import 'package:familysphere_app/features/family/domain/entities/family_activity.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

class FamilyDetailsScreen extends ConsumerStatefulWidget {
  const FamilyDetailsScreen({super.key});

  @override
  ConsumerState<FamilyDetailsScreen> createState() => _FamilyDetailsScreenState();
}

class _FamilyDetailsScreenState extends ConsumerState<FamilyDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyProvider.notifier).loadFamily();
    });
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final family = familyState.family;
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (familyState.isLoading && family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (family == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family')),
        body: const Center(child: Text('No family group found.')),
      );
    }

    final isAdmin = family.isAdmin(user?.id ?? '');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, family, isAdmin, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAdminBanner(isAdmin, isDark),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Family Members', '${familyState.members.length} total'),
                  const SizedBox(height: 16),
                  _buildMembersList(familyState.members, family, user?.id, isDark),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context, 'Recent Activity', 'View all'),
                  const SizedBox(height: 16),
                  _buildActivityFeed(familyState.activities, isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/invite-member'),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Invite'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(BuildContext context, family_entity.Family family, bool isAdmin, bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          family.name,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            // TODO: Family Settings
          },
        ),
      ],
    );
  }

  Widget _buildAdminBanner(bool isAdmin, bool isDark) {
    if (!isAdmin) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          const Text(
            'Admin View',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // TODO: Manage permissions
            },
            child: const Text('Manage Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMembersList(List<FamilyMember> members, family_entity.Family family, String? currentUserId, bool isDark) {
    return Column(
      children: members.map((member) {
        final isMe = member.userId == currentUserId;
        final isAdmin = member.role == 'admin';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              _buildAvatar(member.displayName, isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isMe ? '${member.displayName} (You)' : member.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_user_rounded, color: AppTheme.primaryColor, size: 14),
                        ],
                      ],
                    ),
                    Text(
                      isAdmin ? 'Family Admin' : 'Family Member',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
              if (!isMe && family.isAdmin(currentUserId ?? ''))
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) => _handleMemberAction(value, member),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'role', child: Text('Change Role')),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove Member', style: TextStyle(color: AppTheme.errorColor)),
                    ),
                  ],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvatar(String name, bool isDark) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityFeed(List<FamilyActivity> activities, bool isDark) {
    if (activities.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No recent activity', style: TextStyle(color: AppTheme.textTertiary)),
        ),
      );
    }

    return Column(
      children: activities.take(5).map((activity) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getActivityColor(activity.type).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getActivityIcon(activity.type),
                  color: _getActivityColor(activity.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: activity.actorName ?? 'Someone ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' ${activity.message}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(activity.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'member_joined':
        return AppTheme.successColor;
      case 'member_left':
      case 'member_removed':
        return AppTheme.errorColor;
      case 'family_created':
        return AppTheme.primaryColor;
      default:
        return AppTheme.secondaryColor;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'member_joined':
        return Icons.person_add_rounded;
      case 'member_left':
      case 'member_removed':
        return Icons.person_remove_rounded;
      case 'family_created':
        return Icons.home_work_rounded;
      case 'settings_updated':
        return Icons.tune_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _handleMemberAction(String action, FamilyMember member) async {
    if (action == 'remove') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Member?'),
          content: Text('Are you sure you want to remove ${member.displayName} from the family?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(familyProvider.notifier).removeMember(member.userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${member.displayName} removed')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
            );
          }
        }
      }
    } else if (action == 'role') {
      final isNowAdmin = member.role == 'admin';
      final newRole = isNowAdmin ? 'member' : 'admin';
      
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change Role?'),
          content: Text('Make ${member.displayName} a ${isNowAdmin ? 'Member' : 'Admin'}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(familyProvider.notifier).changeMemberRole(member.userId, newRole);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Role updated for ${member.displayName}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
            );
          }
        }
      }
    }
  }
}
