import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Hub'),
          bottom: TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Messages'),
              Tab(text: 'Family Feed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMessagesTab(context),
            _buildFeedTab(context),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'hub_fab',
          onPressed: () {},
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.edit_note_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMessagesTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildChatItem(
          context,
          name: 'Family Group',
          message: 'Dad: Who is coming for dinner?',
          time: '12:45 PM',
          isGroup: true,
          unreadCount: 3,
        ),
        _buildChatItem(
          context,
          name: 'Sarah (Mom)',
          message: 'Did you pick up the milk?',
          time: '10:30 AM',
          unreadCount: 0,
        ),
        _buildChatItem(
          context,
          name: 'John (Brother)',
          message: 'Check out this cool photo!',
          time: 'Yesterday',
          unreadCount: 0,
        ),
      ],
    );
  }

  Widget _buildFeedTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFeedPost(
          context,
          author: 'Sarah (Mom)',
          time: '2 hours ago',
          content: 'Look at the beautiful sunset today! 🌅',
          hasImage: true,
        ),
        const SizedBox(height: 16),
        _buildFeedPost(
          context,
          author: 'John (Brother)',
          time: '5 hours ago',
          content: 'Just finished my math project! Finally! 📚✅',
          hasImage: false,
        ),
      ],
    );
  }

  Widget _buildChatItem(
    BuildContext context, {
    required String name,
    required String message,
    required String time,
    bool isGroup = false,
    int unreadCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: () {},
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: isGroup ? AppTheme.secondaryColor.withValues(alpha: 0.1) : AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Icon(
          isGroup ? Icons.groups_rounded : Icons.person_rounded,
          color: isGroup ? AppTheme.secondaryColor : AppTheme.primaryColor,
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedPost(
    BuildContext context, {
    required String author,
    required String time,
    required String content,
    required bool hasImage,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(author[0], style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(time, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Icon(Icons.more_horiz_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 16),
            Text(content, style: const TextStyle(fontSize: 15)),
            if (hasImage) ...[
              const SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?auto=format&fit=crop&q=80&w=500'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.favorite_border_rounded, size: 20, color: AppTheme.accentColor),
                const SizedBox(width: 4),
                const Text('4', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline_rounded, size: 20, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                const SizedBox(width: 4),
                const Text('2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
