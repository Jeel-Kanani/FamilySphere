import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

/// Home Screen
/// 
/// Main dashboard displaying family overview and quick actions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load family data once the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyProvider.notifier).loadFamily();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final familyState = ref.watch(familyProvider);
    final family = familyState.family;

    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'FamilySphere'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/family-details');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(familyProvider.notifier).loadFamily(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Section
                Text(
                  'Hello, ${user?.displayName?.split(' ')[0] ?? "User"}! 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                ),
                
                const SizedBox(height: 24),
                
                // Family Members (Face Bubbles)
                if (family != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Family Members',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/family-details'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: familyState.members.length + 1, // +1 for Add button
                      separatorBuilder: (context, index) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        if (index == familyState.members.length) {
                          // Add Member Button
                          return GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/invite-member'),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey.shade200,
                                  child: const Icon(Icons.add, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(height: 8),
                                const Text('Invite', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }

                        final member = familyState.members[index];
                        final isMe = member.userId == user?.id;

                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: isMe ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade200,
                              backgroundImage: member.photoUrl != null 
                                  ? NetworkImage(member.photoUrl!) 
                                  : null,
                              child: member.photoUrl == null
                                  ? Text(
                                      member.displayName.isNotEmpty 
                                          ? member.displayName[0].toUpperCase() 
                                          : '?',
                                      style: TextStyle(
                                        color: isMe ? AppTheme.primaryColor : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isMe ? 'You' : member.displayName.split(' ')[0],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ] else if (familyState.isLoading) ...[
                   const SizedBox(
                     height: 100, 
                     child: Center(
                       child: CircularProgressIndicator(strokeWidth: 2)
                     )
                   ),
                ] else ...[
                  // If no family yet (though AuthChecker handles this)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Connect with your family to get started!'),
                  ),
                ],

                const SizedBox(height: 32),
                
                // Quick Actions / Features Placeholder
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildFeatureCard(
                      context,
                      icon: Icons.calendar_month,
                      title: 'Calendar',
                      color: Colors.blue.shade100,
                      iconColor: Colors.blue,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.check_circle_outline,
                      title: 'Tasks',
                      color: Colors.green.shade100,
                      iconColor: Colors.green,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.folder,
                      title: 'Documents',
                      color: Colors.amber.shade100,
                      iconColor: Colors.amber.shade800,
                      onTap: () => Navigator.pushNamed(context, '/documents'),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.attach_money,
                      title: 'Expenses',
                      color: Colors.orange.shade100,
                      iconColor: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: iconColor.withOpacity(0.1), width: 1),
      ),
      child: InkWell(
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title coming soon!')),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
