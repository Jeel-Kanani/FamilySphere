import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/timeline/domain/entities/timeline_event.dart';
import 'package:familysphere_app/features/timeline/presentation/providers/timeline_provider.dart';
import 'package:familysphere_app/features/timeline/presentation/screens/timeline_screen.dart';

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppTheme.darkBackground, const Color(0xFF0F172A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, ref),
                _buildTabBar(context),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTimelineTab(context),
                      _buildRemindersTab(context, ref),
                      _buildDashboardTab(context, ref),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildPremiumFAB(context, ref),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tracker Hub',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Manage family life smoothly',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          _buildGlassIconButton(context, Icons.refresh_rounded, () {
            ref.invalidate(timelineProvider);
          }),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Timeline'),
          Tab(text: 'Reminders'),
          Tab(text: 'Dashboard'),
        ],
      ),
    );
  }

  // ─── TIMELINE TAB ────────────────────────────────────────────────────────────
  Widget _buildTimelineTab(BuildContext context) {
    return const TimelineScreen();
  }

  // ─── REMINDERS TAB ───────────────────────────────────────────────────────────
  Widget _buildRemindersTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timelineProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final in7Days = now.add(const Duration(days: 7));
    final in30Days = now.add(const Duration(days: 30));

    final todayEvents = state.futureEvents
        .where((e) => e.startDate.isBefore(todayEnd))
        .toList();
    final weekEvents = state.futureEvents
        .where((e) =>
            e.startDate.isAfter(todayEnd) &&
            e.startDate.isBefore(in7Days))
        .toList();
    final monthEvents = state.futureEvents
        .where((e) =>
            e.startDate.isAfter(in7Days) &&
            e.startDate.isBefore(in30Days))
        .toList();

    if (todayEvents.isEmpty && weekEvents.isEmpty && monthEvents.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.notifications_none_rounded,
        'All clear!',
        'No upcoming events in the next 30 days.\nUpload a document and AI will auto-detect dates.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        if (todayEvents.isNotEmpty) ...[
          _buildCategoryTitle('Today'),
          ...todayEvents.map((e) => _buildReminderCard(context, e, now)),
          const SizedBox(height: 8),
        ],
        if (weekEvents.isNotEmpty) ...[
          _buildCategoryTitle('This Week'),
          ...weekEvents.map((e) => _buildReminderCard(context, e, now)),
          const SizedBox(height: 8),
        ],
        if (monthEvents.isNotEmpty) ...[
          _buildCategoryTitle('This Month'),
          ...monthEvents.map((e) => _buildReminderCard(context, e, now)),
        ],
      ],
    );
  }

  Widget _buildReminderCard(
      BuildContext context, TimelineEvent event, DateTime now) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysLeft = event.startDate.difference(now).inDays;
    final color = event.accentColor;
    final progress = daysLeft <= 0
        ? 1.0
        : (1.0 - (daysLeft / 30.0)).clamp(0.0, 1.0);

    String scheduleLabel;
    if (daysLeft == 0) {
      scheduleLabel = 'Today';
    } else if (daysLeft == 1) {
      scheduleLabel = 'Tomorrow';
    } else {
      scheduleLabel = 'In $daysLeft days';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Icon(event.icon, color: color, size: 24),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${event.type.name.toUpperCase()} • $scheduleLabel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          if (event.needsReview)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text(
                'REVIEW',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.orange,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                daysLeft <= 0 ? 'TODAY' : '$daysLeft D',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── DASHBOARD TAB ───────────────────────────────────────────────────────────
  Widget _buildDashboardTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timelineProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final needsReviewCount =
        state.futureEvents.where((e) => e.needsReview).length +
            state.pastEvents.where((e) => e.needsReview).length;
    final billsDueCount = state.futureEvents
        .where((e) => e.type == TimelineEventType.billDue)
        .length;
    final upcomingCount = state.futureEvents
        .where((e) => e.startDate.difference(now).inDays <= 30)
        .length;
    final criticalDeadlines = state.futureEvents
        .where((e) =>
            e.type == TimelineEventType.expiry ||
            e.type == TimelineEventType.billDue)
        .take(5)
        .toList();

    if (state.futureEvents.isEmpty && state.pastEvents.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.dashboard_customize_rounded,
        'No events yet',
        'Upload documents and AI will automatically\nextract dates and deadlines for you.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            _buildGlassStatBox(
              context,
              needsReviewCount > 0 ? 'Needs Review' : 'Reviewed',
              '$needsReviewCount',
              needsReviewCount > 0 ? Colors.orangeAccent : Colors.greenAccent,
            ),
            const SizedBox(width: 16),
            _buildGlassStatBox(
              context,
              'Bills Due',
              '$billsDueCount',
              billsDueCount > 0 ? Colors.redAccent : Colors.blueAccent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildGlassStatBox(
              context,
              'Due in 30d',
              '$upcomingCount',
              Colors.amberAccent,
            ),
            const SizedBox(width: 16),
            _buildGlassStatBox(
              context,
              'Total Events',
              '${state.futureEvents.length + state.pastEvents.length}',
              Colors.purpleAccent,
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (criticalDeadlines.isNotEmpty) ...[
          _buildCategoryTitle('Critical Deadlines'),
          ...criticalDeadlines.map(
            (e) => _buildDashboardDeadlineCard(context, e, now),
          ),
        ] else ...[
          _buildCategoryTitle('Deadlines'),
          _buildEmptyCard(context, 'No expiry or bill-due events found.'),
        ],
        if (state.futureEvents.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildCategoryTitle('Upcoming Events'),
          ...state.futureEvents
              .take(3)
              .map((e) => _buildReminderCard(context, e, now)),
        ],
      ],
    );
  }

  // --- PREMIUM COMPONENT WIDGETS ---

  Widget _buildGlassIconButton(
      BuildContext context, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(icon,
                color: isDark ? Colors.white70 : Colors.black54, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildGlassStatBox(
      BuildContext context, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardDeadlineCard(
      BuildContext context, TimelineEvent event, DateTime now) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysLeft = event.startDate.difference(now).inDays;
    final color =
        daysLeft <= 7 ? Colors.redAccent : Colors.orangeAccent;
    final urgency = (1.0 - (daysLeft / 30.0)).clamp(0.0, 1.0);

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${months[event.startDate.month - 1]} ${event.startDate.day}, ${event.startDate.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${event.type == TimelineEventType.expiry ? 'Exp' : 'Due'}: $dateStr',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                daysLeft <= 0 ? 'TODAY' : '$daysLeft Days',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: urgency,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title,
      String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: isDark ? Colors.white12 : Colors.black12),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }

  // ─── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildPremiumFAB(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _CreateEventSheet(widgetRef: ref),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        label: Text(
          'NEW EVENT',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
      ),
    );
  }
}

// ─── CREATE EVENT BOTTOM SHEET ────────────────────────────────────────────────
class _CreateEventSheet extends StatefulWidget {
  final WidgetRef widgetRef;
  const _CreateEventSheet({required this.widgetRef});

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedType = 'task';
  bool _isLoading = false;

  static const _types = [
    ('task', 'Task', Icons.event_note_rounded, Colors.purpleAccent),
    ('expiry', 'Expiry', Icons.timer_rounded, Colors.orangeAccent),
    ('bill_due', 'Bill Due', Icons.receipt_long_rounded, Colors.redAccent),
    ('birthday', 'Birthday', Icons.cake_rounded, Colors.pinkAccent),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    color: AppTheme.primaryColor, size: 26),
                const SizedBox(width: 10),
                Text(
                  'CREATE EVENT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title input
            TextField(
              controller: _titleController,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Event Title',
                labelStyle: GoogleFonts.plusJakartaSans(
                    color:
                        isDark ? Colors.white38 : Colors.black38),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Type selector
            Text(
              'TYPE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final (value, label, icon, color) = t;
                final selected = _selectedType == value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.2)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: selected ? color : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: selected ? color : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date picker row
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18,
                        color:
                            isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 12),
                    Text(
                      dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'TAP TO CHANGE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _submit(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'ADD EVENT',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event title')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await widget.widgetRef
        .read(timelineProvider.notifier)
        .createEvent(
          title: title,
          type: _selectedType,
          startDate: _selectedDate,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event "$title" added'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create event. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
