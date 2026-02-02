import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_list_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Vault'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => Navigator.pushNamed(context, '/scanner'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context),
          const DocumentListScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-document'),
        label: const Text('Add Document'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Global Vault'),
          const SizedBox(height: 12),
          _buildVaultCard(
            context,
            title: 'Shared Documents',
            subtitle: 'Property, Taxes, Utility Bills',
            icon: Icons.folder_shared_rounded,
            color: Colors.blue,
            tags: ['Property', 'Tax', 'Utilities'],
          ),
          
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Personal Folders'),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Folder', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFolderCard(context, 'Taxes 2025', 5, Colors.amber),
                _buildFolderCard(context, 'Rental', 2, Colors.purple),
                _buildFolderCard(context, 'Medical', 8, Colors.teal),
                _buildFolderCard(context, 'Education', 4, Colors.red),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          _buildSectionHeader('Security Tiers'),
          const SizedBox(height: 12),
            _buildVaultCard(
              context,
              title: 'Identity Vault',
              subtitle: 'Passports, IDs, Certificates',
              icon: Icons.badge_rounded,
              color: AppTheme.successColor,
              tags: ['Passport', 'License', 'ID'],
            ),
          const SizedBox(height: 12),
          _buildVaultCard(
            context,
            title: 'Private Locker',
            subtitle: 'Encrypted & Hidden',
            icon: Icons.lock_rounded,
            color: Colors.orange,
            isLocked: true,
            tags: ['Personal', 'Finance'],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, String title, int count, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.folder_rounded, color: color, size: 32),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$count items',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> tags,
    bool isLocked = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLocked)
                    const Icon(Icons.fingerprint_rounded, color: Colors.orange, size: 20)
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textTertiary),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: tags.map((tag) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
