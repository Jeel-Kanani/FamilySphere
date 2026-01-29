import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/family/domain/entities/family.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';

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
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () {
                              // TODO: Confirm remove
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Remove member not implemented yet')),
                              );
                            },
                          )
                        : null,
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
}
