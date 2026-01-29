import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

/// Family Setup Screen
/// 
/// Fourth screen in authentication flow.
/// User can create a new family or join an existing one.
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _joinCodeController = TextEditingController();
  final _createNameController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    _createNameController.dispose();
    super.dispose();
  }

  void _handleCreateFamily() async {
    final name = _createNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a family name')),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    try {
      await ref.read(familyProvider.notifier).create(name);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create family: $e')),
        );
      }
    }
  }

  void _handleJoinFamily() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-character code')),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    try {
      await ref.read(familyProvider.notifier).join(code);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join family: $e')),
        );
      }
    }
  }

  void _showCreateFamilyDialog(BuildContext context) {
    _createNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Give your family group a name to get started.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _createNameController,
              decoration: const InputDecoration(
                labelText: 'Family Name',
                hintText: 'e.g. The Smiths',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _handleCreateFamily,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinFamilyDialog(BuildContext context) {
    _joinCodeController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 6-character invite code shared by your family admin.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _joinCodeController,
              decoration: const InputDecoration(
                labelText: 'Family Code',
                hintText: 'e.g. ABC123',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _handleJoinFamily,
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);

    // Listen for errors
    ref.listen(familyProvider, (previous, next) {
      if (next.error != null && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: familyState.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    'Create or Join a Family',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Connect with your loved ones',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Create Family Card
                  Card(
                    elevation: 8,
                    shadowColor: AppTheme.primaryColor.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [Colors.white, AppTheme.primaryColor.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showCreateFamilyDialog(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add_circle_outline,
                                  size: 48,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Create New Family',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Start your family hub and invite members',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Join Family Card
                  Card(
                    elevation: 8,
                    shadowColor: AppTheme.secondaryColor.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [Colors.white, AppTheme.secondaryColor.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showJoinFamilyDialog(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.group_add,
                                  size: 48,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Join Existing Family',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Enter a family code to join',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Skip for now
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      ),
    );
  }
}
