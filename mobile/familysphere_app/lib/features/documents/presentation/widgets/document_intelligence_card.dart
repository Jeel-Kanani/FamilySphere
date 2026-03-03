import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:familysphere_app/features/documents/data/models/document_intelligence_model.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_intelligence_provider.dart';

/// Displays AI-extracted intelligence: tags, entities, importance.
/// Wrap it in a document detail screen to show rich metadata.
class DocumentIntelligenceCard extends ConsumerWidget {
  final String docId;

  const DocumentIntelligenceCard({super.key, required this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentIntelligenceProvider(docId));

    return async.when(
      loading: () => const _LoadingShimmer(),
      error: (_, __) => const SizedBox.shrink(), // silently hide if not ready
      data: (intel) => _IntelligenceBody(intel: intel),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _IntelligenceBody extends StatelessWidget {
  final DocumentIntelligenceModel intel;
  const _IntelligenceBody({required this.intel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. AI Brain Insights (NEW) ──────────────────────────────────────
        if (intel.summary != null && intel.summary!.isNotEmpty) ...[
          _AIBrainInsights(summary: intel.summary!),
          const SizedBox(height: 20),
        ],

        // ── 2. Risk & Criticality ──────────────────────────────────────────
        _ImportanceAndRiskRow(intel: intel),
        const SizedBox(height: 20),

        // ── 3. Smart Tags ───────────────────────────────────────────────────
        if (intel.tags.isNotEmpty) ...[
          const _SectionTitle(title: 'Keywords', icon: Icons.auto_awesome_outlined),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: intel.tags.map((tag) => _TagChip(tag: tag, isDark: isDark)).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── 4. Entity Collections (Chips) ──────────────────────────────────
        if (intel.entities.people.isNotEmpty) ...[
          const _SectionTitle(title: 'People Involved', icon: Icons.people_outline_rounded),
          const SizedBox(height: 8),
          _EntityChipGroup(
            chips: intel.entities.people.map((p) => _ChipData(label: p.name, sub: p.role, icon: Icons.person_rounded)).toList(),
            isDark: isDark,
          ),
          const SizedBox(height: 20),
        ],

        if (intel.entities.organizations.isNotEmpty) ...[
          const _SectionTitle(title: 'Organizations', icon: Icons.business_rounded),
          const SizedBox(height: 8),
          _EntityChipGroup(
            chips: intel.entities.organizations.map((o) => _ChipData(label: o.name, sub: o.type, icon: Icons.account_balance_rounded)).toList(),
            isDark: isDark,
          ),
          const SizedBox(height: 20),
        ],

        // ── 5. Detailed Table ──────────────────────────────────────────────
        if (intel.entities.displayPairs.isNotEmpty) ...[
          const _SectionTitle(title: 'Data Extraction', icon: Icons.dataset_rounded),
          const SizedBox(height: 8),
          _EntitiesTable(pairs: intel.entities.displayPairs, isDark: isDark),
          const SizedBox(height: 20),
        ],

        // ── 6. Suggested Events (NEW) ──────────────────────────────────────
        if (intel.suggestedEvents.isNotEmpty) ...[
          const _SectionTitle(title: 'AI Suggestions', icon: Icons.lightbulb_outline_rounded),
          const SizedBox(height: 10),
          ...intel.suggestedEvents.map((e) => _SuggestedEventCard(event: e, isDark: isDark)).toList(),
          const SizedBox(height: 20),
        ],

        // ── 7. Confidence & Technicals ─────────────────────────────────────
        _ConfidenceRow(classification: intel.classification),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Analyzed by ${intel.aiModel} • ${intel.analyzedAt.toString().split('.')[0]}',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.hintColor),
          ),
        ),
      ],
    );
  }
}

// ── NEW: AI Brain Insights ──────────────────────────────────────────────────

class _AIBrainInsights extends StatelessWidget {
  final String summary;
  const _AIBrainInsights({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1A237E).withOpacity(0.3), const Color(0xFF0D47A1).withOpacity(0.1)]
            : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB).withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.blueAccent.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_rounded, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI INSIGHTS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2, color: Colors.blueAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Importance & Risk ─────────────────────────────────────────────────────────

class _ImportanceAndRiskRow extends StatelessWidget {
  final DocumentIntelligenceModel intel;
  const _ImportanceAndRiskRow({required this.intel});

  @override
  Widget build(BuildContext context) {
    final risk = intel.riskAnalysis;
    final isExpired = risk?.isExpired ?? false;
    final expiresSoon = risk?.expiresSoon ?? false;

    return Row(
      children: [
        Expanded(child: _ImportanceBadge(importance: intel.importance)),
        if (isExpired || expiresSoon) ...[
          const SizedBox(width: 12),
          _RiskBadge(isExpired: isExpired),
        ],
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final bool isExpired;
  const _RiskBadge({required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final color = isExpired ? Colors.redAccent : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(isExpired ? Icons.history_rounded : Icons.timer_outlined, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            isExpired ? 'EXPIRED' : 'EXPIRING SOON',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Suggested Events ──────────────────────────────────────────────────────────

class _SuggestedEventCard extends StatelessWidget {
  final SuggestedEvent event;
  final bool isDark;
  const _SuggestedEventCard({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_rounded, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${DateFormat('MMM d, yyyy').format(event.date)} • ${event.eventType}',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {}, // Implementation later
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add to Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Entity Chips ──────────────────────────────────────────────────────────────

class _ChipData {
  final String? label;
  final String? sub;
  final IconData icon;
  _ChipData({this.label, this.sub, required this.icon});
}

class _EntityChipGroup extends StatelessWidget {
  final List<_ChipData> chips;
  final bool isDark;
  const _EntityChipGroup({required this.chips, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.where((c) => c.label != null && c.label!.isNotEmpty).map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.icon, size: 14, color: isDark ? Colors.white38 : Colors.grey),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  if (c.sub != null && c.sub!.isNotEmpty)
                    Text(c.sub!, style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Sub-widgets from current version (re-used/adapted) ────────────────────────

class _ImportanceBadge extends StatelessWidget {
  final DocumentImportance importance;
  const _ImportanceBadge({required this.importance});

  @override
  Widget build(BuildContext context) {
    final color = _criticalityColor(importance.criticality);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_criticalityIcon(importance.criticality), color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                importance.criticality.toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.8),
              ),
              Text(
                'Score ${importance.score}/10',
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _criticalityColor(String c) {
    switch (c) {
      case 'critical':
      case 'high':     return Colors.redAccent;
      case 'medium':   return Colors.blueAccent;
      default:         return Colors.greenAccent;
    }
  }

  IconData _criticalityIcon(String c) {
    switch (c) {
      case 'high':     return Icons.warning_amber_rounded;
      case 'medium':   return Icons.info_rounded;
      default:         return Icons.check_circle_rounded;
    }
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final bool isDark;
  const _TagChip({required this.tag, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('#$tag', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.blue.shade700, fontWeight: FontWeight.bold)),
    );
  }
}

class _EntitiesTable extends StatelessWidget {
  final Map<String, String> pairs;
  final bool isDark;
  const _EntitiesTable({required this.pairs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final entries = pairs.entries.toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: i == entries.length - 1 ? null : Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(entry.key, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey))),
                Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  final DocumentClassification classification;
  const _ConfidenceRow({required this.classification});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = classification.confidencePercent;
    final color = pct >= 70 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red;

    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 12, color: isDark ? Colors.white38 : Colors.grey),
        const SizedBox(width: 6),
        Text('AI CONFIDENCE: $pct%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey)),
        const SizedBox(width: 10),
        Expanded(
          child: LinearProgressIndicator(
            value: classification.confidence,
            minHeight: 3,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.hintColor),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.bold, color: theme.hintColor)),
      ],
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
  }
}
