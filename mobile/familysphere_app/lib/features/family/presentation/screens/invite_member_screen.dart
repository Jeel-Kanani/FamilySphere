import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';

class InviteMemberScreen extends ConsumerWidget {
  const InviteMemberScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyProvider);
    final family = familyState.family;
    final currentUser = ref.watch(authProvider).user;

    if (family == null) {
      return const Scaffold(
        body: Center(child: Text('Family not found')),
      );
    }

    final isAdmin = family.isAdmin(currentUser?.id ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Members'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Invite Family Members',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this code with your family members so they can join your family group.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    family.inviteCode,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: family.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy Code',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final message = 'Join my family on FamilySphere. Use invite code: ${family.inviteCode}';
                  await Share.share(message, subject: 'FamilySphere Invite');
                },
                icon: const Icon(Icons.share),
                label: const Text('Share Code'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (familyState.isLoading)
              const CircularProgressIndicator()
            else
              TextButton.icon(
                onPressed: isAdmin
                    ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Generate new code?'),
                            content: const Text('Old invite links will stop working.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Generate'),
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
                icon: const Icon(Icons.refresh),
                label: const Text('Generate New Code'),
              ),
          ],
        ),
      ),
    );
  }
}
