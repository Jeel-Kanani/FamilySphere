import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/intelligence/presentation/providers/intelligence_provider.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/document_intelligence_card.dart';

class IntelligenceHubScreen extends ConsumerStatefulWidget {
  const IntelligenceHubScreen({super.key});

  @override
  ConsumerState<IntelligenceHubScreen> createState() => _IntelligenceHubScreenState();
}

class _IntelligenceHubScreenState extends ConsumerState<IntelligenceHubScreen>
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
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimations = List.generate(_sectionCount, (i) {
      final start = i * 0.1;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnimations = List.generate(_sectionCount, (i) {
      final start = i * 0.1;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    _staggerController.forward();
    
    // Fetch intelligence data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(intelligenceProvider.notifier).fetchBriefing();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docState = ref.watch(documentProvider);
    final intelState = ref.watch(intelligenceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final analyzedDocs = docState.documents.where((d) => 
      d.ocrStatus == 'done' || 
      d.ocrStatus == 'analyzed' || 
      d.ocrStatus == 'needs_confirmation'
    ).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(intelligenceProvider.notifier).fetchBriefing(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section 0: Header ──
                _animatedSection(
                  index: 0,
                  child: _buildHeader(context, analyzedDocs.length, isDark),
                ),
                const SizedBox(height: 28),

                // ── Section 1: Domain Entry Points (Phase 3) ──
                _animatedSection(
                  index: 1,
                  child: _buildDomainGrid(context, isDark),
                ),
                const SizedBox(height: 32),

                // ── Section 2: Daily Briefing (Actionable) ──
                _animatedSection(
                  index: 2,
                  child: _buildBriefingSection(context, intelState, isDark),
                ),
                const SizedBox(height: 32),

                // ── Section 3: Recent Intelligence ──
                _animatedSection(
                  index: 3,
                  child: _buildRecentIntel(context, analyzedDocs, isDark),
                ),
                const SizedBox(height: 24),

                // ── Section 4: Intelligence Footer ──
                _animatedSection(
                  index: 4,
                  child: _buildFooter(context, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedSection({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: child,
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, int count, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Intel Hub',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Text(
              'AI-powered document insights',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_rounded, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── DOMAIN GRID (PHASE 3: 4 DOMAINS) ────────────────────────────────────────
  Widget _buildDomainGrid(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INTELLIGENCE DOMAINS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
             _buildDomainCard(
              context: context,
              title: 'Documents',
              subtitle: 'Storage & Extraction',
              icon: Icons.description_rounded,
              color: Colors.blueAccent,
              isDark: isDark,
            ),
             _buildDomainCard(
              context: context,
              title: 'Expenses',
              subtitle: 'Financial Insights',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.greenAccent,
              isDark: isDark,
            ),
             _buildDomainCard(
              context: context,
              title: 'Calendar',
              subtitle: 'Smart Schedule',
              icon: Icons.calendar_today_rounded,
              color: Colors.orangeAccent,
              isDark: isDark,
            ),
             _buildDomainCard(
              context: context,
              title: 'Daily Brief',
              subtitle: 'Personalized Feed',
              icon: Icons.tips_and_updates_rounded,
              color: Colors.purpleAccent,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDomainCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── DAILY BRIEFING (PHASE 3: ACTIONABLE) ───────────────────────────────────
  Widget _buildBriefingSection(BuildContext context, IntelligenceState state, bool isDark) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final briefings = state.briefings;
    if (briefings.isEmpty) {
      return const SizedBox.shrink(); // Hide if no recommendations
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DAILY BRIEFING',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.purpleAccent,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'AI Powered',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.purpleAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...briefings.take(3).map((b) => _buildBriefingItem(context, b, isDark)).toList(),
      ],
    );
  }

  Widget _buildBriefingItem(BuildContext context, IntelligenceBriefing briefing, bool isDark) {
    final color = _getPriorityColor(briefing.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getCategoryIcon(briefing.category),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  briefing.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  briefing.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical': return Colors.redAccent;
      case 'high': return Colors.orangeAccent;
      case 'medium': return Colors.blueAccent;
      default: return Colors.greenAccent;
    }
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('financial')) return Icons.account_balance_wallet_rounded;
    if (cat.contains('identity')) return Icons.badge_rounded;
    if (cat.contains('medical')) return Icons.medical_services_rounded;
    if (cat.contains('legal')) return Icons.gavel_rounded;
    return Icons.auto_awesome_rounded;
  }


  // ─── RECENT INTEL ────────────────────────────────────────────────────────────
  Widget _buildRecentIntel(BuildContext context, List<DocumentEntity> docs, bool isDark) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_fix_normal_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              'No analyzed documents',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a document to see AI insights',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT INSIGHTS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...docs.take(5).map((doc) => _buildIntelCard(context, doc, isDark)).toList(),
      ],
    );
  }

  Widget _buildIntelCard(BuildContext context, DocumentEntity doc, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor.withOpacity(0.08), AppTheme.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
          ),
          title: Text(
            doc.title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            doc.category,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DocumentIntelligenceCard(docId: doc.id),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FOOTER ──────────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.shield_moon_outlined, color: AppTheme.primaryColor, size: 32),
          const SizedBox(height: 16),
          Text(
            'Keep your data safe',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'FamilySphere Intelligence runs securely. Your data stays private and encrypted within your family vault.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

