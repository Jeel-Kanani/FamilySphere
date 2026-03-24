import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/family/domain/entities/family_invite.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  FamilyInvite? _activeInvite;
  bool _isLoadingInvite = false;
  String _selectedRole = 'member';

  @override
  void initState() {
    super.initState();
    _generateInitialInvite();
  }

  Future<void> _generateInitialInvite() async {
    setState(() => _isLoadingInvite = true);
    try {
      final invite = await ref.read(familyProvider.notifier).createFamilyInvite('qr', targetRole: _selectedRole);
      setState(() {
        _activeInvite = invite;
        _isLoadingInvite = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInvite = false);
        _showError('Failed to generate invite: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider).family;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (family == null) {
      return const Scaffold(body: Center(child: Text('Family not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Member'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            _buildRoleSelection(isDark),
            const SizedBox(height: 32),
            _buildQrSection(isDark),
            const SizedBox(height: 48),
            _buildCodeSection(isDark),
            const SizedBox(height: 48),
            _buildInfoSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildQrSection(bool isDark) {
    return Column(
      children: [
        const Text(
          'Scan to Join',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Show this QR code to a family member',
          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _isLoadingInvite
              ? const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _activeInvite != null
                  ? QrImageView(
                      data: _activeInvite!.token,
                      version: QrVersions.auto,
                      size: 200.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.circle,
                        color: AppTheme.primaryColor,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: Text(
                          'Generating...',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _isLoadingInvite ? null : _generateInitialInvite,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh / Regenerate'),
        ),
      ],
    );
  }

  Widget _buildRoleSelection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invite as',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _roleOption(
              'Member',
              'member',
              Icons.person_rounded,
              'Can upload and edit documents',
              isDark,
            ),
            const SizedBox(width: 12),
            _roleOption(
              'Viewer',
              'viewer',
              Icons.visibility_rounded,
              'Read-only access to documents',
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _roleOption(String title, String role, IconData icon, String subtitle, bool isDark) {
    final isSelected = _selectedRole == role;
    final color = isSelected ? AppTheme.primaryColor : (isDark ? Colors.white70 : Colors.grey[600]);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedRole = role);
          _generateInitialInvite();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.primaryColor.withOpacity(0.1) 
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Or use a code',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite Code',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeInvite?.code ?? 'Generating...',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  if (_activeInvite?.code != null) {
                    Clipboard.setData(ClipboardData(text: _activeInvite!.code!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () {
                  if (_activeInvite != null) {
                    final link = 'familysphere://join?token=${_activeInvite!.token}';
                    Share.share('Join my family on FamilySphere! Use code: ${_activeInvite!.code} or click: $link');
                  }
                },
                icon: const Icon(Icons.share_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'This invite will expire in 48 hours for security purposes.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
