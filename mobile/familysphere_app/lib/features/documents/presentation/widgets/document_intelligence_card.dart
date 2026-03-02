import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final pairs = intel.entities.displayPairs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Importance Badge ─────────────────────────────────────────────────
        _ImportanceBadge(importance: intel.importance),
        const SizedBox(height: 16),

        // ── Smart Tags ───────────────────────────────────────────────────────
        if (intel.tags.isNotEmpty) ...[
          const _SectionTitle(title: 'Smart Tags', icon: Icons.label_outline_rounded),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: intel.tags
                .map((tag) => _TagChip(tag: tag, isDark: isDark))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Extracted Entities (Key-Value) ───────────────────────────────────
        if (pairs.isNotEmpty) ...[
          const _SectionTitle(title: 'Document Details', icon: Icons.info_outline_rounded),
          const SizedBox(height: 8),
          _EntitiesTable(pairs: pairs, isDark: isDark),
          const SizedBox(height: 20),
        ],

        // ── AI Confidence ────────────────────────────────────────────────────
        _ConfidenceRow(classification: intel.classification),
      ],
    );
  }
}

// ── Importance Badge ──────────────────────────────────────────────────────────

class _ImportanceBadge extends StatelessWidget {
  final DocumentImportance importance;
  const _ImportanceBadge({required this.importance});

  @override
  Widget build(BuildContext context) {
    final color = _criticalityColor(importance.criticality);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_criticalityIcon(importance.criticality), color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                importance.criticality.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${importance.lifecycleStage.replaceAll('-', ' ')} · Score ${importance.score}/10',
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Score dial
          _ScoreDial(score: importance.score, color: color),
        ],
      ),
    );
  }

  Color _criticalityColor(String c) {
    switch (c) {
      case 'critical': return const Color(0xFFE53935);
      case 'high':     return const Color(0xFFFF6F00);
      case 'medium':   return const Color(0xFF1E88E5);
      default:         return const Color(0xFF43A047);
    }
  }

  IconData _criticalityIcon(String c) {
    switch (c) {
      case 'critical': return Icons.error_rounded;
      case 'high':     return Icons.warning_amber_rounded;
      case 'medium':   return Icons.info_rounded;
      default:         return Icons.check_circle_rounded;
    }
  }
}

class _ScoreDial extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreDial({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 10,
            strokeWidth: 3,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag Chip ──────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String tag;
  final bool isDark;
  const _TagChip({required this.tag, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0xFF1E88E5).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : const Color(0xFF1E88E5),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Entities Table ────────────────────────────────────────────────────────────

class _EntitiesTable extends StatelessWidget {
  final Map<String, String> pairs;
  final bool isDark;
  const _EntitiesTable({required this.pairs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final entries = pairs.entries.toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final isLast = i == entries.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.grey.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Confidence Row ────────────────────────────────────────────────────────────

class _ConfidenceRow extends StatelessWidget {
  final DocumentClassification classification;
  const _ConfidenceRow({required this.classification});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = classification.confidencePercent;
    final color = pct >= 70
        ? const Color(0xFF43A047)
        : pct >= 50
            ? const Color(0xFFFF6F00)
            : const Color(0xFFE53935);

    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 14, color: isDark ? Colors.white38 : Colors.grey),
        const SizedBox(width: 6),
        Text(
          'AI Confidence: $pct%',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: classification.confidence,
              minHeight: 4,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 15, color: isDark ? Colors.white54 : Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 16,
          width: double.infinity * (i == 2 ? 0.6 : 1),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
