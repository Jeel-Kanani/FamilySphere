import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _cardColor = Colors.white;
  static const Color _cardColorAlt = Color(0xFFF1F5F9);
  static const Color _actionBlue = Color(0xFF2D8CFF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyProvider.notifier).loadFamily();
      ref.read(documentProvider.notifier).loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final familyState = ref.watch(familyProvider);
    final documentsState = ref.watch(documentProvider);
    final displayName = user?.displayName ?? 'User';
    final familyName = familyState.family?.name ?? '${displayName} Family';
    final members = _buildMemberCards(familyState);
    final docCards = _buildDocumentCards(documentsState);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, familyName),
              const SizedBox(height: 24),
              _buildSectionTitle(context, title: 'Quick Actions'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      title: 'Scan Document',
                      icon: Icons.document_scanner_rounded,
                      color: _actionBlue,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.scanner),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      title: 'Upload File',
                      icon: Icons.cloud_upload_rounded,
                      color: _cardColorAlt,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.addDocument),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                context,
                title: 'Family Members',
                trailing: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.familyDetails),
                  child: const Text('Manage'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 138,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _buildMemberCard(context, members[index]),
                ),
              ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                context,
                title: 'Common Documents',
                trailing: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.documents),
                  child: const Text('See All'),
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.1,
                children: docCards.map((item) => _buildDocumentCard(context, item)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String familyName) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: _cardColorAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: const Icon(Icons.group_rounded, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning,',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                familyName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_rounded),
            color: AppTheme.textPrimary,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (trailing != null)
          DefaultTextStyle(
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _actionBlue,
                ) ??
                const TextStyle(color: _actionBlue),
            child: trailing,
          ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final textColor = color == _cardColorAlt ? AppTheme.textPrimary : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: color == _cardColorAlt ? Border.all(color: AppTheme.borderColor) : null,
        ),
        child: SizedBox(
          height: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color == _cardColorAlt
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  icon,
                  color: color == _cardColorAlt ? AppTheme.primaryColor : Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, _MemberCardData member) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    member.initials,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              if (member.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            member.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            member.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, _DocumentCardData item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.iconBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 20),
          ),
          const Spacer(),
          Text(
            item.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  List<_MemberCardData> _buildMemberCards(FamilyState familyState) {
    if (familyState.members.isNotEmpty) {
      return familyState.members.take(4).toList().asMap().entries.map((entry) {
        final member = entry.value;
        return _MemberCardData(
          name: member.displayName.isEmpty ? 'Member' : member.displayName,
          subtitle: member.role.displayName,
          isOnline: entry.key == 0,
        );
      }).toList();
    }

    return const [
      _MemberCardData(name: 'Dad', subtitle: 'Admin', isOnline: true),
      _MemberCardData(name: 'Mom', subtitle: 'Member', isOnline: false),
      _MemberCardData(name: 'Brother', subtitle: 'Member', isOnline: false),
      _MemberCardData(name: 'Sister', subtitle: 'Member', isOnline: false),
    ];
  }

  List<_DocumentCardData> _buildDocumentCards(DocumentState documentsState) {
    final baseCount = documentsState.documents.length;
    final identityCount = baseCount == 0 ? 12 : (baseCount / 4).round().clamp(1, 99);
    final insuranceCount = baseCount == 0 ? 8 : (baseCount / 5).round().clamp(1, 99);
    final utilityCount = baseCount == 0 ? 24 : (baseCount / 3).round().clamp(1, 99);
    final propertyCount = baseCount == 0 ? 6 : (baseCount / 6).round().clamp(1, 99);

    return [
      _DocumentCardData(
        title: 'Identity Proofs',
        subtitle: '$identityCount Documents',
        icon: Icons.badge_rounded,
        iconColor: const Color(0xFF3B82F6),
        iconBackground: const Color(0xFF1E3A8A),
      ),
      _DocumentCardData(
        title: 'Insurance Policies',
        subtitle: '$insuranceCount Documents',
        icon: Icons.shield_rounded,
        iconColor: const Color(0xFF22C55E),
        iconBackground: const Color(0xFF14532D),
      ),
      _DocumentCardData(
        title: 'Utility Bills',
        subtitle: '$utilityCount Documents',
        icon: Icons.receipt_long_rounded,
        iconColor: const Color(0xFFF97316),
        iconBackground: const Color(0xFF7C2D12),
      ),
      _DocumentCardData(
        title: 'Property Docs',
        subtitle: '$propertyCount Documents',
        icon: Icons.home_work_rounded,
        iconColor: const Color(0xFF8B5CF6),
        iconBackground: const Color(0xFF4C1D95),
      ),
    ];
  }
}

class _MemberCardData {
  final String name;
  final String subtitle;
  final bool isOnline;

  const _MemberCardData({
    required this.name,
    required this.subtitle,
    required this.isOnline,
  });

  String get initials {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _DocumentCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  const _DocumentCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });
}
