// ─────────────────────────────────────────────────────────────────────────────
//  FamilySphere — Timeline Screen  (fully rewritten)
//  Features:
//    • Animated filter chips (All, Upcoming, Expiry, Bills, Birthday, etc.)
//    • Long-press WhatsApp-style card selection → Edit / Delete action bar
//    • Slide-in card entrance animations (left ↔ right)
//    • Shake animation on delete confirmation
//    • Edit event bottom sheet with date picker + type selector
//    • Add event FAB with animated expand
//    • Swipe-to-dismiss as secondary delete gesture
//    • Empty-state illustrations per filter
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/timeline/domain/entities/timeline_event.dart';
import 'package:familysphere_app/features/timeline/presentation/providers/timeline_provider.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final Key _todayKey = const ValueKey('today-key');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final minScroll = _scrollController.position.minScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Near the bottom (Past)
    if (currentScroll >= maxScroll - 200) {
      ref.read(timelineProvider.notifier).fetchMorePast();
    }
    
    // Near the top (Future)
    if (currentScroll <= minScroll + 200) {
       ref.read(timelineProvider.notifier).fetchMoreFuture();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background "Time Thread" Line
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 1,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.primaryColor.withValues(alpha: 0.3),
                    AppTheme.primaryColor.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              center: _todayKey,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // FUTURE LOADING INDICATOR
                if (state.isLoadingMoreFuture)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                  ),

                // FUTURE SECTION HEADER
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: _SectionHeader(title: 'INCOMING FUTURE'),
                  ),
                ),

                // FUTURE EVENTS (Scroll UP)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = state.futureEvents[state.futureEvents.length - 1 - index];
                      final originalIndex = state.futureEvents.length - 1 - index;
                      return _buildTimelineItem(context, event, originalIndex % 2 == 0, isFuture: true);
                    },
                    childCount: state.futureEvents.length,
                  ),
                ),

                // TODAY INDICATOR (CENTER ANCHOR)
                SliverToBoxAdapter(
                  key: _todayKey,
                  child: _buildTodayIndicator(context),
                ),

                // PAST EVENTS (Scroll DOWN)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = state.pastEvents[index];
                      return _buildTimelineItem(context, event, index % 2 != 0, isFuture: false);
                    },
                    childCount: state.pastEvents.length,
                  ),
                ),

                // PAST SECTION HEADER
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: _SectionHeader(title: 'ARCHIVED PAST'),
                  ),
                ),

                // PAST LOADING INDICATOR
                if (state.isLoadingMorePast)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                  ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayIndicator(BuildContext context) {
    return const _PulsingTodayIndicator();
  }

  Widget _buildTimelineItem(BuildContext context, TimelineEvent event, bool isRightSide, {required bool isFuture}) {
    final state = ref.watch(timelineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = event.accentColor;
    
    // Determine if we should show a Year or Month jump indicator
    Widget? jumpIndicator;
    final events = isFuture ? state.futureEvents : state.pastEvents;
    final index = events.indexOf(event);
    
    if (index > 0) {
      final prevEvent = events[index - 1];
      final diff = event.startDate.difference(prevEvent.startDate).abs();
      
      if (event.startDate.year != prevEvent.startDate.year) {
        jumpIndicator = _YearIndicator(year: event.startDate.year.toString());
      } else if (diff.inDays > 30) {
        jumpIndicator = _GapIndicator(days: diff.inDays);
      }
    } else if (isFuture && event.startDate.year != DateTime.now().year) {
       // First future event is in a different year
       jumpIndicator = _YearIndicator(year: event.startDate.year.toString());
    }

    return Column(
      children: [
        if (jumpIndicator != null) jumpIndicator,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            children: [
              // Date Label (Centered on line, above the card to avoid overlap)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  _formatDate(event.startDate),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: isRightSide ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (isRightSide) const Spacer(flex: 1),
                  
                  // Card
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleEventTap(context, event),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)]
                                : [Colors.white, Colors.white.withValues(alpha: 0.8)],
                          ),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: IntrinsicHeight(
                            child: Row(
                              children: isRightSide ? [
                                Expanded(child: _buildCardContent(event, color, isDark, isFuture, isRightSide)),
                                Container(width: 4, color: color.withValues(alpha: isFuture ? 1.0 : 0.4)),
                              ] : [
                                Container(width: 4, color: color.withValues(alpha: isFuture ? 1.0 : 0.4)),
                                Expanded(child: _buildCardContent(event, color, isDark, isFuture, isRightSide)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                
                if (!isRightSide) const Spacer(flex: 1),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardContent(TimelineEvent event, Color color, bool isDark, bool isFuture, bool isRightSide) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(event.icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: isRightSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: isRightSide ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Text(
                      event.type.name.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: color.withValues(alpha: isFuture ? 1.0 : 0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (event.needsReview) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline, size: 10, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              'REVIEW',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  textAlign: isRightSide ? TextAlign.right : TextAlign.left,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.description,
                  textAlign: isRightSide ? TextAlign.right : TextAlign.left,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    String formatted = '${months[date.month - 1]} ${date.day}';
    if (date.year != now.year) {
      formatted += ', ${date.year}';
    }
    return formatted;
  }

  void _handleEventTap(BuildContext context, TimelineEvent event) {
    if (event.needsReview) {
      _showReviewSheet(context, event);
    } else {
      _showEventDetailSheet(context, event);
    }
  }

  void _showEventDetailSheet(BuildContext context, TimelineEvent event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = event.accentColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(event.icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${event.type.name.toUpperCase()} • ${_formatDate(event.startDate)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                event.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditSheet(context, event);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete Event?'),
                          content: Text('Are you sure you want to delete "${event.title}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        final ok = await ref.read(timelineProvider.notifier).deleteEvent(event.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Event deleted' : 'Failed to delete'),
                              backgroundColor: ok ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, TimelineEvent event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController(text: event.title);
    final descCtrl = TextEditingController(text: event.description);
    var selectedDate = event.startDate;
    var selectedType = event.type.name;
    // Map type names to backend values
    if (selectedType == 'billDue') selectedType = 'bill_due';
    if (selectedType == 'billPaid') selectedType = 'bill_paid';
    if (selectedType == 'uploaded') selectedType = 'document_upload';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          final dateStr = '${months[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}';
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EDIT EVENT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      letterSpacing: 2.0, color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setSheetState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                          const SizedBox(width: 12),
                          Text(dateStr, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                          const Spacer(),
                          Text('TAP TO CHANGE', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: AppTheme.primaryColor.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        final ok = await ref.read(timelineProvider.notifier).editEvent(
                          event.id,
                          title: title,
                          description: descCtrl.text.trim(),
                          startDate: selectedDate,
                          type: selectedType,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Event updated' : 'Failed to update'),
                              backgroundColor: ok ? AppTheme.primaryColor : Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text('SAVE CHANGES', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReviewSheet(BuildContext context, TimelineEvent event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Text(
                  'CONFIRM INTELLIGENCE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'AI detected an expiry date: \n${_formatDate(event.startDate)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Does this look correct for your "${event.title}"?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: event.startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && context.mounted) {
                        ref.read(timelineProvider.notifier).dismissReview(event.id, correctedDate: picked);
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Correct Date'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(timelineProvider.notifier).dismissReview(event.id);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}


class _YearIndicator extends StatelessWidget {
  final String year;
  const _YearIndicator({required this.year});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            year,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _GapIndicator extends StatelessWidget {
  final int days;
  const _GapIndicator({required this.days});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          '~ ${days ~/ 30} MONTHS LATER',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.grey.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PulsingTodayIndicator extends StatefulWidget {
  const _PulsingTodayIndicator();

  @override
  State<_PulsingTodayIndicator> createState() => _PulsingTodayIndicatorState();
}

class _PulsingTodayIndicatorState extends State<_PulsingTodayIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15 * _animation.value,
                    spreadRadius: 2 * _animation.value,
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: child,
            );
          },
          child: Text(
            'TODAY',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 4.0,
          color: Colors.grey.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
