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
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final familyState = ref.watch(familyProvider);
    final documentsState = ref.watch(documentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final displayName = user?.displayName ?? 'User';
    final familyName = familyState.family?.name ?? '${displayName} Family';
    final members = _buildMemberCards(familyState);
    final docCards = _buildDocumentCards(documentsState);

    final pageBackground = isDark ? AppTheme.darkBackground : AppTheme.backgroundColor;
    final cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryBlue = AppTheme.primaryColor;
    final lightBlue = isDark ? AppTheme.darkSurfaceVariant : const Color(0xFFEFF6FF);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.borderColor;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, familyName, cardColor, borderColor, textPrimary, textSecondary),
              const SizedBox(height: 24),
              _buildSectionTitle(context, title: 'Quick Actions', textSecondary: textSecondary),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      title: 'Scan Document',
                      icon: Icons.document_scanner_rounded,
                      color: primaryBlue,
                      borderColor: borderColor,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.scanner),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      title: 'Upload File',
                      icon: Icons.cloud_upload_rounded,
                      color: lightBlue,
                      borderColor: borderColor,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.addDocument),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                context,
                title: 'Family Members',
                textSecondary: textSecondary,
                trailing: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.familyDetails),
                  child: Text('Manage', style: TextStyle(color: primaryBlue)),
                ),
              ),
              const SizedBox(height: 14),
              if (familyState.isLoading && familyState.members.isEmpty)
                const SizedBox(
                  height: 138,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (members.isEmpty)
                Container(
                  height: 90,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    'No family members found',
                    style: TextStyle(color: textSecondary),
                  ),
                )
              else
                SizedBox(
                  height: 138,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _buildMemberCard(context, members[index], textPrimary, cardColor),
                  ),
                ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                context,
                title: 'Common Documents',
                textSecondary: textSecondary,
                trailing: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.documents),
                  child: Text('See All', style: TextStyle(color: primaryBlue)),
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
                children: docCards.map((item) => _buildDocumentCard(context, item, cardColor, borderColor, textPrimary, textSecondary)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String familyName, Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.group_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning,',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                familyName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(color: borderColor),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_rounded),
            color: textPrimary,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context, {
    required String title,
    required Color textSecondary,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textSecondary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (trailing != null)
          DefaultTextStyle(
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ) ??
                const TextStyle(color: AppTheme.primaryColor),
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
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final isPrimary = color == AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isPrimary ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.primaryColor);
    final iconColor = isPrimary ? Colors.white : AppTheme.primaryColor;
    final iconBg = isPrimary 
        ? Colors.white.withValues(alpha: 0.2) 
        : AppTheme.primaryColor.withValues(alpha: 0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: !isPrimary ? Border.all(color: borderColor) : null,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: SizedBox(
          height: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, _MemberCardData member, Color textPrimary, Color cardColor) {
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
                  color: cardColor,
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
                      border: Border.all(color: cardColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            member.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textPrimary,
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

  Widget _buildDocumentCard(BuildContext context, _DocumentCardData item, Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: borderColor),
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
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textSecondary,
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

    return const [];
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
        iconColor: const Color(0xFF2563EB),
        iconBackground: const Color(0xFFEFF6FF),
      ),
      _DocumentCardData(
        title: 'Insurance Policies',
        subtitle: '$insuranceCount Documents',
        icon: Icons.shield_rounded,
        iconColor: const Color(0xFF10B981),
        iconBackground: const Color(0xFFECFDF5),
      ),
      _DocumentCardData(
        title: 'Utility Bills',
        subtitle: '$utilityCount Documents',
        icon: Icons.receipt_long_rounded,
        iconColor: const Color(0xFFF97316),
        iconBackground: const Color(0xFFFFF7ED),
      ),
      _DocumentCardData(
        title: 'Property Docs',
        subtitle: '$propertyCount Documents',
        icon: Icons.home_work_rounded,
        iconColor: const Color(0xFF3B82F6),
        iconBackground: const Color(0xFFDBEAFE),
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
