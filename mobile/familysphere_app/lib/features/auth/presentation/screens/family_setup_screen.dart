import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen>
    with TickerProviderStateMixin {
  final _createNameController = TextEditingController();
  String _selectedTemplate = '🏢 Team Workspace';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> _templates = [
    {'name': '🏢 Team Workspace', 'hint': 'e.g. Acme Marketing'},
    {'name': '🚀 Project Space', 'hint': 'e.g. Product Launch Alpha'},
    {'name': '📁 Personal Vault', 'hint': 'e.g. My Private Space'},
    {'name': '🏠 Household Space', 'hint': 'e.g. Home & Records'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.slowAnimation,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _createNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleCreateWorkspace() async {
    final name = _createNameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    try {
      await ref.read(familyProvider.notifier).create(name);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor, behavior: SnackBarBehavior.floating),
    );
  }

  void _showCreateDialog() {
    _createNameController.text = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.workspaces_rounded, color: AppTheme.primaryColor, size: 24),
              SizedBox(width: 10),
              Text('New Workspace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a template:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _templates.map((tpl) {
                  final isSelected = _selectedTemplate == tpl['name'];
                  return ChoiceChip(
                    label: Text(tpl['name']!, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (val) {
                      if (val) {
                        setDialogState(() {
                          _selectedTemplate = tpl['name']!;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _createNameController,
                decoration: InputDecoration(
                  labelText: 'Workspace Name',
                  hintText: _templates.firstWhere((t) => t['name'] == _selectedTemplate)['hint'],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleCreateWorkspace,
              child: const Text('Create Workspace'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: familyState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspaces_rounded,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Setup Your Workspace',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a collaborative space for shared documents, encrypted vault notes, and team intelligence.',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      _buildActionCard(
                        context,
                        title: 'Create a Workspace',
                        desc: 'Start a new hub with shared folders & vaults',
                        icon: Icons.add_business_rounded,
                        color: AppTheme.primaryColor,
                        onTap: _showCreateDialog,
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        context,
                        title: 'Join a Workspace',
                        desc: 'Enter an invite code or scan a workspace QR',
                        icon: Icons.group_add_rounded,
                        color: AppTheme.secondaryColor,
                        onTap: () => Navigator.pushNamed(context, '/join-family'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                        child: const Text('Continue to Dashboard', style: TextStyle(color: AppTheme.textTertiary)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
