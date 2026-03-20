import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/confirm_type_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  static const int _sectionCount = 5;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimations = List.generate(_sectionCount, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnimations = List.generate(_sectionCount, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    _staggerController.forward();

    // Load global documents for the "Recent" section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentProvider.notifier).loadDocuments(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final familyState = ref.watch(familyProvider);
    final documentsState = ref.watch(documentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = user?.displayName ?? 'User';
    final firstName = displayName.split(' ').first;
    final familyName = familyState.family?.name ?? '$displayName Family';
    final memberCount = familyState.members.length;
    final docCount = documentsState.documents.length;
    final storageUsed = documentsState.storageUsed;
    final storageLimit = documentsState.storageLimit;
    final storagePercent =
        storageLimit > 0 ? (storageUsed / storageLimit).clamp(0.0, 1.0) : 0.0;

    final bg = isDark ? AppTheme.darkBackground : AppTheme.backgroundColor;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final border = isDark ? AppTheme.darkBorder : AppTheme.borderColor;
    final textP = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textS = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 0: Header ──
              _animatedSection(
                index: 0,
                child: _buildHeader(context, firstName, cardBg, border, textP,
                    textS, isDark, documentsState),
              ),
              const SizedBox(height: 28),

              // ── Section 1: Family Overview Card ──
              _animatedSection(
                index: 1,
                child: _buildFamilyCard(context, familyName, memberCount,
                    familyState, textP, cardBg, isDark),
              ),
              const SizedBox(height: 24),

              // ── Section 2: Quick Actions ──
              _animatedSection(
                index: 2,
                child:
                    _buildQuickActions(context, isDark, cardBg, border, textP),
              ),
              const SizedBox(height: 24),

              // ── Section 3: Storage Overview ──
              _animatedSection(
                index: 3,
                child: _buildStorageCard(
                    context,
                    storageUsed,
                    storageLimit,
                    storagePercent,
                    docCount,
                    cardBg,
                    border,
                    textP,
                    textS,
                    isDark),
              ),
              const SizedBox(height: 24),

              // ── Section 4: Recent Activity ──
              _animatedSection(
                index: 4,
                child: _buildRecentDocs(context, documentsState, cardBg, border,
                    textP, textS, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Animated section wrapper
  // ────────────────────────────────────────────────────────────
  Widget _animatedSection({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: child,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  0 · Header
  // ────────────────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context,
      String firstName,
      Color cardBg,
      Color border,
      Color textP,
      Color textS,
      bool isDark,
      DocumentState documentsState) {
    final pendingCount = documentsState.documents
        .where((d) =>
            d.ocrStatus == 'needs_confirmation' || d.ocrStatus == 'analyzed')
        .length;
    return Row(
      children: [
        // Gradient avatar
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()} ${_getGreetingEmoji()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textS,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textP,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
              ),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          cardBg: cardBg,
          border: border,
          textP: textP,
          badgeCount: pendingCount,
          onTap: () => _showNotificationPanel(
            context,
            documentsState.documents
                .where((d) =>
                    d.ocrStatus == 'needs_confirmation' ||
                    d.ocrStatus == 'analyzed')
                .toList(),
            isDark,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Notification Panel
  // ────────────────────────────────────────────────────────────
  void _showNotificationPanel(
    BuildContext context,
    List<DocumentEntity> pendingDocs,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationPanel(
        pendingDocs: pendingDocs,
        isDark: isDark,
        onAllConfirmed: () {
          ref.read(documentProvider.notifier).loadDocuments();
          Navigator.pop(context);
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  1 · Family Overview Card
  // ────────────────────────────────────────────────────────────
  Widget _buildFamilyCard(
      BuildContext context,
      String familyName,
      int memberCount,
      FamilyState familyState,
      Color textP,
      Color cardBg,
      bool isDark) {
    final members = familyState.members.take(5).toList();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.familyDetails),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E3A5F), const Color(0xFF0F172A)]
                : [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Family name + arrow
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        familyName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Member avatars row
            if (familyState.isLoading && members.isEmpty)
              SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              )
            else if (members.isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Invite your family members',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                ),
              )
            else
              Row(
                children: [
                  // Stacked avatars
                  SizedBox(
                    height: 40,
                    width: (members.length.clamp(1, 5) * 28.0) + 12,
                    child: Stack(
                      children: List.generate(members.length.clamp(0, 5), (i) {
                        final m = members[i];
                        final initials = _getInitials(m.displayName);
                        return Positioned(
                          left: i * 28.0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _avatarGradient(i),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1E3A5F)
                                    : AppTheme.primaryColor,
                                width: 2.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Manage',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  2 · Quick Actions
  // ────────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isDark, Color cardBg,
      Color border, Color textP) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textP,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.document_scanner_rounded,
                label: 'Scan',
                gradient: AppTheme.primaryGradient,
                onTap: () => Navigator.pushNamed(context, AppRoutes.scanner),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.cloud_upload_rounded,
                label: 'Upload',
                gradient: AppTheme.accentGradient,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.addDocument),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.folder_rounded,
                label: 'Vault',
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.documents),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.auto_awesome_rounded,
                label: 'Intel',
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.intelligence),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  3 · Storage Overview
  // ────────────────────────────────────────────────────────────
  Widget _buildStorageCard(
      BuildContext context,
      int storageUsed,
      int storageLimit,
      double storagePercent,
      int docCount,
      Color cardBg,
      Color border,
      Color textP,
      Color textS,
      bool isDark) {
    // Show in MB if < 1 GB, otherwise in GB
    final usedGB = storageUsed / (1024 * 1024 * 1024);
    final limitGB = storageLimit / (1024 * 1024 * 1024);
    final usedLabel = usedGB < 1
        ? '${(storageUsed / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${usedGB.toStringAsFixed(2)} GB';
    final limitLabel = '${limitGB.toStringAsFixed(0)} GB';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_done_rounded,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: textP,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '$docCount documents stored',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: textS,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '$usedLabel / $limitLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textS,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: storagePercent),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? AppTheme.darkSurfaceVariant
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(
                    value > 0.85
                        ? AppTheme.errorColor
                        : value > 0.6
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.documents),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('View All Documents'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                    color: AppTheme.primaryColor.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  4 · Recent Documents
  // ────────────────────────────────────────────────────────────
  Widget _buildRecentDocs(BuildContext context, DocumentState documentsState,
      Color cardBg, Color border, Color textP, Color textS, bool isDark) {
    final recentDocs = documentsState.documents.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Documents',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textP,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (recentDocs.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.recentDocuments),
                child: Text(
                  'See All',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (documentsState.isLoading && recentDocs.isEmpty)
          Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (recentDocs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: textS.withOpacity(0.5),
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  'No documents yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textS,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan or upload your first document',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textS.withOpacity(0.7),
                      ),
                ),
              ],
            ),
          )
        else
          ...recentDocs.asMap().entries.map((entry) {
            final doc = entry.value;
            final isLast = entry.key == recentDocs.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: _RecentDocTile(
                title: doc.title,
                category: doc.category,
                cardBg: cardBg,
                border: border,
                textP: textP,
                textS: textS,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.documentViewer,
                  arguments: doc,
                ),
              ),
            );
          }),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Helpers
  // ────────────────────────────────────────────────────────────
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  List<Color> _avatarGradient(int index) {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF818CF8)],
      [Color(0xFF10B981), Color(0xFF34D399)],
      [Color(0xFFF97316), Color(0xFFFBBF24)],
      [Color(0xFFEC4899), Color(0xFFF472B6)],
      [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    ];
    return palettes[index % palettes.length];
  }
}

// ══════════════════════════════════════════════════════════════
//  Extracted Stateless Widgets
// ══════════════════════════════════════════════════════════════

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final Color cardBg;
  final Color border;
  final Color textP;
  final VoidCallback onTap;
  final int badgeCount;

  const _HeaderIconButton({
    required this.icon,
    required this.cardBg,
    required this.border,
    required this.textP,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  static const _amber = Color(0xFFF59E0B);
  static const _amberDeep = Color(0xFFFF6F00);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    if (widget.badgeCount > 0) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_HeaderIconButton old) {
    super.didUpdateWidget(old);
    if (widget.badgeCount > 0 && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (widget.badgeCount == 0 && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasBadge = widget.badgeCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Pulsing glow ring
        if (hasBadge)
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _amber.withValues(alpha: _pulseAnim.value * 0.45),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        Material(
          color: hasBadge ? _amber.withOpacity(0.1) : widget.cardBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      hasBadge ? _amber.withOpacity(0.55) : widget.border,
                  width: hasBadge ? 1.5 : 1.0,
                ),
              ),
              child: Icon(
                hasBadge ? Icons.notifications_active_rounded : widget.icon,
                color: hasBadge ? _amber : widget.textP,
                size: 22,
              ),
            ),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_amberDeep, _amber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _amber.withOpacity(0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
              child: Text(
                '${widget.badgeCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 26),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDocTile extends StatelessWidget {
  final String title;
  final String category;
  final Color cardBg;
  final Color border;
  final Color textP;
  final Color textS;
  final VoidCallback onTap;

  const _RecentDocTile({
    required this.title,
    required this.category,
    required this.cardBg,
    required this.border,
    required this.textP,
    required this.textS,
    required this.onTap,
  });

  IconData _iconForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'identity':
        return Icons.badge_rounded;
      case 'insurance':
        return Icons.shield_rounded;
      case 'utility':
        return Icons.receipt_long_rounded;
      case 'property':
        return Icons.home_work_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Color _colorForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'identity':
        return const Color(0xFF2563EB);
      case 'insurance':
        return const Color(0xFF10B981);
      case 'utility':
        return const Color(0xFFF97316);
      case 'property':
        return const Color(0xFF3B82F6);
      case 'medical':
        return const Color(0xFFEC4899);
      case 'education':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _colorForCategory(category);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForCategory(category),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textP,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: textS,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: textS,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
//  Notification Panel Bottom Sheet  (redesigned)
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationPanel extends ConsumerStatefulWidget {
  final List<DocumentEntity> pendingDocs;
  final bool isDark;
  final VoidCallback onAllConfirmed;

  const _NotificationPanel({
    required this.pendingDocs,
    required this.isDark,
    required this.onAllConfirmed,
  });

  @override
  ConsumerState<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends ConsumerState<_NotificationPanel>
    with SingleTickerProviderStateMixin {
  late List<DocumentEntity> _remaining;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late final AnimationController _allClearCtrl;
  late final Animation<double> _allClearScale;

  @override
  void initState() {
    super.initState();
    _remaining = List.from(widget.pendingDocs);
    _allClearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _allClearScale = CurvedAnimation(
      parent: _allClearCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _allClearCtrl.dispose();
    super.dispose();
  }

  void _onDocConfirmed(String docId) {
    final index = _remaining.indexWhere((d) => d.id == docId);
    if (index < 0) return;
    final removed = _remaining[index];
    setState(() => _remaining.removeAt(index));
    _listKey.currentState?.removeItem(
      index,
      (_, anim) => _buildRemovedCard(removed, anim),
      duration: const Duration(milliseconds: 350),
    );
    ref.read(documentProvider.notifier).loadDocuments();
    if (_remaining.isEmpty) {
      _allClearCtrl.forward();
      widget.onAllConfirmed();
    }
  }

  Widget _buildRemovedCard(DocumentEntity doc, Animation<double> anim) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeIn),
      child: FadeTransition(
        opacity: anim,
        child: _DocConfirmCard(
          doc: doc,
          isDark: widget.isDark,
          onConfirmed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textP = isDark ? Colors.white : const Color(0xFF0F172A);
    final textS = isDark ? Colors.white60 : const Color(0xFF64748B);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.65, 0.94],
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 32,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Drag pill ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Gradient header ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6F00), Color(0xFFF59E0B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _remaining.isEmpty
                          ? Icons.check_circle_rounded
                          : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Action Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _remaining.isEmpty
                              ? 'All confirmed – you\'re all set!'
                              : '${_remaining.length} document${_remaining.length > 1 ? 's' : ''} need your review',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_remaining.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_remaining.length} pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _remaining.isEmpty
                    ? _buildAllClearView(isDark, textP, textS)
                    : AnimatedList(
                        key: _listKey,
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        initialItemCount: _remaining.length,
                        itemBuilder: (_, i, anim) {
                          final doc = _remaining[i];
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.08, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            )),
                            child: FadeTransition(
                              opacity: anim,
                              child: _DocConfirmCard(
                                doc: doc,
                                isDark: isDark,
                                onConfirmed: () => _onDocConfirmed(doc.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllClearView(bool isDark, Color textP, Color textS) {
    return ScaleTransition(
      scale: _allClearScale,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All documents confirmed!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textP,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re fully up to date.',
              style: TextStyle(fontSize: 13, color: textS),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single expandable Document Confirmation Card
// ─────────────────────────────────────────────────────────────────────────────

class _DocConfirmCard extends StatefulWidget {
  final DocumentEntity doc;
  final bool isDark;
  final VoidCallback onConfirmed;

  const _DocConfirmCard({
    required this.doc,
    required this.isDark,
    required this.onConfirmed,
  });

  @override
  State<_DocConfirmCard> createState() => _DocConfirmCardState();
}

class _DocConfirmCardState extends State<_DocConfirmCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _chevronCtrl;
  late final Animation<double> _chevronTurn;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _amber = Color(0xFFF59E0B);
  static const _amberDeep = Color(0xFFFF6F00);
  static const _amberBg = Color(0xFFFFFBEB);

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _chevronTurn = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _chevronCtrl.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevronCtrl.forward();
    } else {
      _chevronCtrl.reverse();
    }
  }

  IconData _iconForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'identity':
        return Icons.badge_rounded;
      case 'insurance':
        return Icons.shield_rounded;
      case 'utility':
        return Icons.receipt_long_rounded;
      case 'property':
        return Icons.home_work_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final isDark = widget.isDark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textP = isDark ? Colors.white : const Color(0xFF0F172A);
    final textS = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderColor =
        isDark ? _amber.withOpacity(0.3) : _amber.withOpacity(0.45);
    final confidenceBg = isDark ? const Color(0xFF2D1F00) : _amberBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left accent strip ──────────────────────────────────────
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_amberDeep, _amber],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // ── Card content ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Summary row ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category icon bubble
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _iconForCategory(doc.category),
                              color: _amberDeep,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: textP,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.folder_rounded,
                                        size: 12, color: textS),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${doc.category} › ${doc.folder}',
                                        style: TextStyle(
                                            fontSize: 11, color: textS),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Uploaded ${_fmtDate(doc.uploadedAt)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textS.withOpacity(0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Confidence chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: confidenceBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _amber.withOpacity(0.5)),
                            ),
                            child: Text(
                              doc.ocrStatus == 'analyzed'
                                  ? 'AI: Review'
                                  : 'AI: Low',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _amberDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Review toggle button ──────────────────────────────
                    if (!_expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: GestureDetector(
                          onTap: _toggleExpanded,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_amberDeep, _amber],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _amber.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.fact_check_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Review & Confirm Type',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ── Expanded confirm area ─────────────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      child: _expanded
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Collapse handle
                                  GestureDetector(
                                    onTap: _toggleExpanded,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.auto_awesome_rounded,
                                            size: 14, color: _amberDeep),
                                        const SizedBox(width: 6),
                                        Text(
                                          'AI detected type – please confirm',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textS,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        RotationTransition(
                                          turns: _chevronTurn,
                                          child: Icon(
                                            Icons.keyboard_arrow_up_rounded,
                                            size: 18,
                                            color: textS,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ConfirmTypeBanner(
                                    docId: doc.id,
                                    aiDetectedType: doc.docType ?? '',
                                    onConfirmed: widget.onConfirmed,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
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
