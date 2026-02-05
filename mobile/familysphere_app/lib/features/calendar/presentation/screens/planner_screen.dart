import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Planner'),
          bottom: TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Calendar'),
              Tab(text: 'Tasks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCalendarTab(context),
            _buildTasksTab(context),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'planner_fab',
          onPressed: () {},
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add_task_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCalendarTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly Calendar View
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('February 2026', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Icon(Icons.chevron_right_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final isToday = index == 0; // Just for UI
                    return Column(
                      children: [
                        Text(days[index], style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isToday ? AppTheme.primaryColor : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            (index + 2).toString(),
                            style: TextStyle(
                              color: isToday ? Colors.white : (isDark ? Colors.white : AppTheme.textPrimary),
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Upcoming Events',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildEventItem(
            context,
            title: 'Family Dinner',
            time: '6:30 PM - 8:00 PM',
            color: Colors.orange,
            attendees: 4,
          ),
          _buildEventItem(
            context,
            title: 'Sarah\'s Piano Lesson',
            time: '4:00 PM - 5:00 PM',
            color: Colors.blue,
            attendees: 1,
          ),
            _buildEventItem(
              context,
              title: 'Trash Collection',
              time: '7:00 AM',
              color: AppTheme.successColor,
              attendees: 2,
            ),
        ],
      ),
    );
  }

  Widget _buildTasksTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildTaskItem(context, 'Buy groceries for the week', 'High', true),
        _buildTaskItem(context, 'Fix the kitchen sink', 'Medium', false),
        _buildTaskItem(context, 'Renew car insurance', 'High', false),
        _buildTaskItem(context, 'Plan summer vacation', 'Low', false),
      ],
    );
  }

  Widget _buildEventItem(
    BuildContext context, {
    required String title,
    required String time,
    required Color color,
    required int attendees,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: List.generate(
              attendees > 3 ? 3 : attendees,
              (index) => Transform.translate(
                offset: Offset(-8.0 * index, 0),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 12, color: AppTheme.primaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, String title, String priority, bool isDone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = priority == 'High' ? Colors.red : (priority == 'Medium' ? Colors.orange : Colors.blue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isDone,
            onChanged: (v) {},
            activeColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isDone ? AppTheme.textTertiary : (isDark ? Colors.white : AppTheme.textPrimary),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              priority,
              style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
