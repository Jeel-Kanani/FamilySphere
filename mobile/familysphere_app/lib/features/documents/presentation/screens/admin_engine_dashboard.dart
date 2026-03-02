import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class _AiMeta {
  final String? docType;
  final String? category;
  final double confidence;
  final bool needsConfirmation;
  final List<String> tags;
  final int? importanceScore;
  final String? criticality;
  final String? lifecycleStage;
  final int suggestedEventsCount;
  final Map<String, dynamic> entities;
  final String? aiModel;
  final DateTime? analyzedAt;

  const _AiMeta({
    required this.docType,
    required this.category,
    required this.confidence,
    required this.needsConfirmation,
    required this.tags,
    required this.importanceScore,
    required this.criticality,
    required this.lifecycleStage,
    required this.suggestedEventsCount,
    required this.entities,
    required this.aiModel,
    required this.analyzedAt,
  });

  factory _AiMeta.fromJson(Map<String, dynamic> j) => _AiMeta(
        docType:              j['docType'] as String?,
        category:             j['category'] as String?,
        confidence:           (j['confidence'] as num?)?.toDouble() ?? 0,
        needsConfirmation:    j['needsConfirmation'] as bool? ?? false,
        tags:                 (j['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
        importanceScore:      j['importanceScore'] as int?,
        criticality:          j['criticality'] as String?,
        lifecycleStage:       j['lifecycleStage'] as String?,
        suggestedEventsCount: j['suggestedEventsCount'] as int? ?? 0,
        entities:             (j['entities'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {},
        aiModel:              j['aiModel'] as String?,
        analyzedAt:           j['analyzedAt'] != null
                                ? DateTime.tryParse(j['analyzedAt'].toString())
                                : null,
      );

  int get entitiesCount => entities.values.where((v) => v != null && v.toString().isNotEmpty).length;
  int get confidencePercent => (confidence * 100).round();
}

class _DocPipelineItem {
  final String id;
  final String title;
  final String category;
  final String folder;
  final String? familyId;
  final String ocrStatus;
  final int rawTextLength;
  final String stage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final _AiMeta? ai;
  final int eventCount;

  const _DocPipelineItem({
    required this.id,
    required this.title,
    required this.category,
    required this.folder,
    required this.familyId,
    required this.ocrStatus,
    required this.rawTextLength,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    required this.ai,
    required this.eventCount,
  });

  factory _DocPipelineItem.fromJson(Map<String, dynamic> j) => _DocPipelineItem(
        id:            j['id'].toString(),
        title:         j['title']?.toString() ?? 'Untitled',
        category:      j['category']?.toString() ?? '',
        folder:        j['folder']?.toString() ?? '',
        familyId:      j['familyId']?.toString(),
        ocrStatus:     j['ocrStatus']?.toString() ?? 'pending',
        rawTextLength: j['rawTextLength'] as int? ?? 0,
        stage:         j['stage']?.toString() ?? 'pending',
        createdAt:     DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt:     DateTime.tryParse(j['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        ai:            j['ai'] != null ? _AiMeta.fromJson(j['ai'] as Map<String, dynamic>) : null,
        eventCount:    j['eventCount'] as int? ?? 0,
      );
}

class _DashboardData {
  final int total;
  final Map<String, int> stages;
  final bool queueEnabled;
  final Map<String, dynamic>? queue;
  final List<_DocPipelineItem> documents;

  const _DashboardData({
    required this.total,
    required this.stages,
    required this.queueEnabled,
    required this.queue,
    required this.documents,
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final _dashboardProvider = FutureProvider.autoDispose<_DashboardData>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/admin/engine-dashboard');
  final d = res.data as Map<String, dynamic>;
  final summary = d['summary'] as Map<String, dynamic>;
  final docs = (d['documents'] as List)
      .map((j) => _DocPipelineItem.fromJson(j as Map<String, dynamic>))
      .toList();
  return _DashboardData(
    total:        summary['total'] as int? ?? 0,
    stages:       (summary['stages'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
    queueEnabled: summary['queueEnabled'] as bool? ?? false,
    queue:        summary['queue'] as Map<String, dynamic>?,
    documents:    docs,
  );
});

final _requeueProvider = StateNotifierProvider.autoDispose<_RequeueNotifier, AsyncValue<String?>>((ref) {
  return _RequeueNotifier(ref.read(apiClientProvider));
});

class _RequeueNotifier extends StateNotifier<AsyncValue<String?>> {
  final ApiClient _api;
  _RequeueNotifier(this._api) : super(const AsyncValue.data(null));

  Future<void> requeue() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.post('/api/admin/requeue-stuck');
      state = AsyncValue.data(res.data['message']?.toString() ?? 'Done');
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }
}

// ─── Stage config ─────────────────────────────────────────────────────────────

const _stageConfig = {
  'pending':          (color: Color(0xFFF59E0B), icon: Icons.schedule_rounded,           label: 'Pending'),
  'processing':       (color: Color(0xFF3B82F6), icon: Icons.sync_rounded,               label: 'OCR Running'),
  'ocr_done_no_ai':   (color: Color(0xFFEAB308), icon: Icons.text_snippet_outlined,      label: 'OCR Done / No AI'),
  'needs_confirmation':(color: Color(0xFFF97316), icon: Icons.help_outline_rounded,       label: 'Needs Confirm'),
  'ai_done':          (color: Color(0xFF10B981), icon: Icons.auto_awesome_rounded,        label: 'AI Done'),
  'events_created':   (color: Color(0xFF6366F1), icon: Icons.event_available_rounded,    label: 'Events Created'),
  'failed':           (color: Color(0xFFEF4444), icon: Icons.error_outline_rounded,      label: 'Failed'),
};

// ─── Main Screen ──────────────────────────────────────────────────────────────

class AdminEngineDashboard extends ConsumerStatefulWidget {
  const AdminEngineDashboard({super.key});

  @override
  ConsumerState<AdminEngineDashboard> createState() => _AdminEngineDashboardState();
}

class _AdminEngineDashboardState extends ConsumerState<AdminEngineDashboard>
    with SingleTickerProviderStateMixin {
  String _filterStage = 'all';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dashAsync = ref.watch(_dashboardProvider);
    final requeueState = ref.watch(_requeueProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Engine Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Requeue button
          requeueState.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
            data: (msg) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Re-queue stuck documents',
              onPressed: () async {
                await ref.read(_requeueProvider.notifier).requeue();
                ref.invalidate(_dashboardProvider);
                final m = ref.read(_requeueProvider).value;
                if (m != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(m),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
            error: (e, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.red),
              onPressed: () => ref.read(_requeueProvider.notifier).requeue(),
            ),
          ),
          // Refresh dashboard
          IconButton(
            icon: const Icon(Icons.replay_rounded),
            tooltip: 'Refresh dashboard',
            onPressed: () => ref.invalidate(_dashboardProvider),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e.toString()),
        data: (data) => _buildBody(context, isDark, data),
      ),
    );
  }

  // ── Loading & Error ─────────────────────────────────────────────────────────

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 16),
            Text('Loading engine data…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );

  Widget _buildError(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text('Failed to load dashboard', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(_dashboardProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  // ── Main Body ───────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, bool isDark, _DashboardData data) {
    final filtered = _filterStage == 'all'
        ? data.documents
        : data.documents.where((d) => d.stage == _filterStage).toList();

    return CustomScrollView(
      slivers: [
        // ─ Stats header ─
        SliverToBoxAdapter(child: _buildStatsSection(context, isDark, data)),

        // ─ Queue status ─
        if (data.queue != null)
          SliverToBoxAdapter(child: _buildQueueCard(isDark, data)),

        // ─ Stage filter chips ─
        SliverToBoxAdapter(child: _buildFilterChips(isDark, data)),

        // ─ Count badge ─
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${filtered.length} document${filtered.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
        ),

        // ─ Document list ─
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildDocCard(ctx, isDark, filtered[i]),
            childCount: filtered.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ── Stats section ────────────────────────────────────────────────────────────

  Widget _buildStatsSection(BuildContext context, bool isDark, _DashboardData data) {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Text(
                'Smart Document Engine',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: data.queueEnabled
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: data.queueEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: data.queueEnabled ? _pulseAnim.value : 1.0,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: data.queueEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      data.queueEnabled ? 'Queue Active' : 'Queue Offline',
                      style: TextStyle(
                        fontSize: 10,
                        color: data.queueEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Big total
          Text(
            '${data.total} Documents',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          // Stage grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _stageConfig.entries.map((entry) {
              final count = data.stages[entry.key] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              final cfg = entry.value;
              return _StageStatChip(
                label: cfg.label,
                count: count,
                color: cfg.color,
                icon: cfg.icon,
                selected: _filterStage == entry.key,
                onTap: () => setState(() =>
                    _filterStage = _filterStage == entry.key ? 'all' : entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Queue Card ───────────────────────────────────────────────────────────────

  Widget _buildQueueCard(bool isDark, _DashboardData data) {
    final q = data.queue!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.queue_rounded, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Text(
                'BullMQ OCR Queue',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QueueStat(label: 'Waiting',   value: q['waiting']   ?? 0, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _QueueStat(label: 'Active',    value: q['active']    ?? 0, color: const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _QueueStat(label: 'Completed', value: q['completed'] ?? 0, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _QueueStat(label: 'Failed',    value: q['failed']    ?? 0, color: const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                _QueueStat(label: 'Delayed',   value: q['delayed']   ?? 0, color: const Color(0xFF94A3B8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────────

  Widget _buildFilterChips(bool isDark, _DashboardData data) {
    final all = [
      ('all', 'All', Icons.layers_rounded, isDark ? Colors.white : const Color(0xFF1E293B)),
      ..._stageConfig.entries
          .where((e) => (data.stages[e.key] ?? 0) > 0)
          .map((e) => (e.key, e.value.label, e.value.icon, e.value.color)),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (key, label, icon, color) = all[i];
          final selected = _filterStage == key;
          return GestureDetector(
            onTap: () => setState(() => _filterStage = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color : (isDark ? AppTheme.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? color : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14,
                      color: selected ? Colors.white : color),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Document card ────────────────────────────────────────────────────────────

  Widget _buildDocCard(BuildContext context, bool isDark, _DocPipelineItem doc) {
    final cfg = _stageConfig[doc.stage] ??
        (color: Colors.grey, icon: Icons.help_outline, label: doc.stage);
    final isProcessing = doc.stage == 'processing';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isProcessing
              ? cfg.color.withValues(alpha: 0.6)
              : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
          width: isProcessing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title + stage badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StageBadge(
                  label: cfg.label,
                  color: cfg.color,
                  icon: cfg.icon,
                  pulse: isProcessing,
                  animation: _pulseAnim,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: folder/category path
            Text(
              '${doc.category} › ${doc.folder}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            // Pipeline progress bar
            _PipelineBar(stage: doc.stage),
            const SizedBox(height: 12),
            // OCR info row
            _buildOcrRow(isDark, doc),
            // AI info (if available)
            if (doc.ai != null) ...[
              const SizedBox(height: 8),
              _buildAiRow(isDark, doc.ai!),
            ],
            // Events row
            if (doc.eventCount > 0 || doc.ai?.suggestedEventsCount != null && (doc.ai?.suggestedEventsCount ?? 0) > 0) ...[
              const SizedBox(height: 8),
              _buildEventsRow(isDark, doc),
            ],
            // Entities (if any)
            if (doc.ai != null && doc.ai!.entitiesCount > 0) ...[
              const SizedBox(height: 8),
              _buildEntitiesRow(isDark, doc.ai!),
            ],
            // Tags
            if (doc.ai != null && doc.ai!.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildTags(isDark, doc.ai!.tags),
            ],
            const SizedBox(height: 8),
            // Footer: timestamp
            Text(
              'Uploaded ${_relTime(doc.createdAt)} · Updated ${_relTime(doc.updatedAt)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrRow(bool isDark, _DocPipelineItem doc) {
    return Row(
      children: [
        const Icon(Icons.document_scanner_rounded, size: 13, color: Colors.grey),
        const SizedBox(width: 5),
        Text(
          'OCR: ${doc.ocrStatus.toUpperCase()}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.text_fields_rounded, size: 13, color: Colors.grey),
        const SizedBox(width: 5),
        Text(
          '${doc.rawTextLength} chars extracted',
          style: TextStyle(
            fontSize: 11,
            color: doc.rawTextLength == 0 ? const Color(0xFFEF4444) : Colors.grey,
            fontWeight: doc.rawTextLength == 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildAiRow(bool isDark, _AiMeta ai) {
    final confColor = ai.confidence >= 0.70
        ? const Color(0xFF10B981)
        : ai.confidence >= 0.50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF6366F1)),
            const SizedBox(width: 5),
            Text(
              ai.docType ?? 'Unknown type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              ai.category ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Spacer(),
            // Confidence pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: confColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: confColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${ai.confidencePercent}% conf.',
                style: TextStyle(
                  fontSize: 10,
                  color: confColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        // Confidence bar
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ai.confidence,
            minHeight: 4,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(confColor),
          ),
        ),
        if (ai.needsConfirmation) ...[
          const SizedBox(height: 5),
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFF97316)),
              SizedBox(width: 4),
              Text(
                'Needs user confirmation (low confidence)',
                style: TextStyle(fontSize: 11, color: Color(0xFFF97316), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
        if (ai.lifecycleStage != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.loop_rounded, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Lifecycle: ${ai.lifecycleStage}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (ai.importanceScore != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.priority_high_rounded, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Importance: ${ai.importanceScore}/10  (${ai.criticality ?? ''})',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEventsRow(bool isDark, _DocPipelineItem doc) {
    final ai = doc.ai;
    final suggested = ai?.suggestedEventsCount ?? 0;
    final created = doc.eventCount;

    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF6366F1)),
        const SizedBox(width: 5),
        Text(
          '$suggested suggested • $created created',
          style: TextStyle(
            fontSize: 11,
            color: created > 0
                ? const Color(0xFF10B981)
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
            fontWeight: created > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (suggested > 0 && created == 0)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text(
              '⚠ 0 timeline entries added',
              style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildEntitiesRow(bool isDark, _AiMeta ai) {
    final pairs = ai.entities.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .take(3)
        .toList();
    if (pairs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        const Icon(Icons.account_tree_rounded, size: 12, color: Colors.grey),
        ...pairs.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_entityLabel(e.key)}: ${e.value}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            )),
        if (ai.entitiesCount > 3)
          Text(
            '+${ai.entitiesCount - 3} more',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildTags(bool isDark, List<String> tags) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.take(5).map((t) => Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
              ),
              child: Text(
                '#$t',
                style: const TextStyle(fontSize: 10, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
              ),
            )).toList(),
      ),
    );
  }

  String _entityLabel(String key) => switch (key) {
        'person_name'  => 'Name',
        'id_number'    => 'ID',
        'issued_by'    => 'Issued by',
        'issue_date'   => 'Issued',
        'expiry_date'  => 'Expires',
        'due_date'     => 'Due',
        'amount'       => 'Amount',
        'institution'  => 'Institution',
        'address'      => 'Address',
        _ => key,
      };

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Pipeline progress bar ────────────────────────────────────────────────────

class _PipelineBar extends StatelessWidget {
  final String stage;
  const _PipelineBar({required this.stage});

  static const _stages = [
    'pending', 'processing', 'ocr_done_no_ai', 'ai_done',
    'needs_confirmation', 'events_created',
  ];

  @override
  Widget build(BuildContext context) {
    if (stage == 'failed') {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Center(
          child: Text('FAILED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        ),
      );
    }

    // Map to progress 0-6
    final progressMap = {
      'pending': 0,
      'processing': 1,
      'ocr_done_no_ai': 2,
      'needs_confirmation': 3,
      'ai_done': 4,
      'events_created': 5,
    };
    final step = progressMap[stage] ?? 0;
    final total = 5;

    final labels = ['Queued', 'OCR', 'Analyzed', 'Confirmed', 'Timeline'];

    return Column(
      children: [
        Row(
          children: List.generate(total, (i) {
            final filled = i < step;
            final active = i == step - 1 ||
                (stage == 'needs_confirmation' && i == 2) ||
                (stage == 'ocr_done_no_ai' && i == 1);
            final color = filled
                ? const Color(0xFF6366F1)
                : active
                    ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0);
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < total - 1 ? 3 : 0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(labels.length, (i) {
            final active = i == step - 1;
            return Expanded(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 9,
                  color: active ? const Color(0xFF6366F1) : Colors.grey.shade400,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Stage badge ──────────────────────────────────────────────────────────────

class _StageBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool pulse;
  final Animation<double> animation;

  const _StageBadge({
    required this.label,
    required this.color,
    required this.icon,
    required this.pulse,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (pulse) {
      return AnimatedBuilder(
        animation: animation,
        builder: (_, __) => Opacity(opacity: animation.value, child: badge),
      );
    }
    return badge;
  }
}

// ─── Stage stat chip ──────────────────────────────────────────────────────────

class _StageStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StageStatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white.withValues(alpha: 0.9) : color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Queue stat chip ──────────────────────────────────────────────────────────

class _QueueStat extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;

  const _QueueStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
