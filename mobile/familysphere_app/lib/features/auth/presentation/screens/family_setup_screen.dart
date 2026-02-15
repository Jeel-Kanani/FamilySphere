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
  final _joinCodeController = TextEditingController();
  final _createNameController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _joinCodeController.dispose();
    _createNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleCreateFamily() async {
    final name = _createNameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    try {
      await ref.read(familyProvider.notifier).create(name);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _handleJoinFamily() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 6) return;
    Navigator.pop(context);
    try {
      await ref.read(familyProvider.notifier).join(code);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Family'),
        content: TextField(
          controller: _createNameController,
          decoration: const InputDecoration(labelText: 'Family Name', hintText: 'e.g. The Smiths'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _handleCreateFamily, child: const Text('Create')),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Family'),
        content: TextField(
          controller: _joinCodeController,
          decoration: const InputDecoration(labelText: 'Invite Code', hintText: 'ABC123'),
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _handleJoinFamily, child: const Text('Join')),
        ],
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'Connect Family',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Start a new family group or join an existing one to stay connected',
                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 64),
                      _buildActionCard(
                        context,
                        title: 'Create a Family',
                        desc: 'Start a new hub and invite others',
                        icon: Icons.add_home_work_rounded,
                        color: AppTheme.primaryColor,
                        onTap: _showCreateDialog,
                      ),
                      const SizedBox(height: 20),
                      _buildActionCard(
                        context,
                        title: 'Join a Family',
                        desc: 'Enter a code or scan a QR code',
                        icon: Icons.group_add_rounded,
                        color: AppTheme.secondaryColor,
                        onTap: () => Navigator.pushNamed(context, '/join-family'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                        child: const Text('Skip for now', style: TextStyle(color: AppTheme.textTertiary)),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(desc, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
