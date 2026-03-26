import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/processing_indicator.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();

    Future.microtask(() async {
      final documents = ref.read(documentProvider.notifier).loadDocuments();
      final folders =
          ref.read(documentProvider.notifier).loadFolders(category: 'Shared');
      final family = ref.read(familyProvider.notifier).loadFamily();
      await Future.wait([documents, folders, family]);

      // Recalculate storage after loading documents to ensure accuracy
      ref.read(documentProvider.notifier).recalculateStorage();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(documentProvider.select((s) => s.isLoading));
    final documents = ref.watch(documentProvider.select((s) => s.documents));
    final storageUsed =
        ref.watch(documentProvider.select((s) => s.storageUsed));
    final storageLimit =
        ref.watch(documentProvider.select((s) => s.storageLimit));
    final lastStorageSync =
        ref.watch(documentProvider.select((s) => s.lastStorageSync));
    final pendingSyncJobs =
        ref.watch(documentProvider.select((s) => s.pendingSyncJobs));
    final failedSyncJobs =
        ref.watch(documentProvider.select((s) => s.failedSyncJobs));
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin == true;
    final isViewer = user?.isViewer == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final border = isDark ? AppTheme.darkBorder : AppTheme.borderColor;

    final storageUsedStr = _formatBytes(storageUsed);
    final storageLimitStr = _formatBytes(storageLimit);
    final progress = storageLimit > 0
        ? (storageUsed / storageLimit).clamp(0, 1).toDouble()
        : 0.0;

    // Recalculate storage after loading documents to ensure accuracy

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(documentProvider.notifier).loadDocuments(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _buildHeader(
                context,
                isLoading,
                isAdmin,
                pendingSyncJobs,
                failedSyncJobs,
              ),

              // Phase 6 – Background Processing Indicator
              if (documents.any((doc) =>
                  doc.ocrStatus == 'pending' || doc.ocrStatus == 'processing'))
                ProcessingIndicator(
                  count: documents
                      .where((doc) =>
                          doc.ocrStatus == 'pending' ||
                          doc.ocrStatus == 'processing')
                      .length,
                ),

              if (pendingSyncJobs > 0 || failedSyncJobs > 0) ...[
                const SizedBox(height: 12),
                _buildSyncBanner(context, pendingSyncJobs, failedSyncJobs),
              ],

              const SizedBox(height: 16),

              const SizedBox(height: 16),

              // Statistics Row
              _buildStatsRow(context, documents),
              const SizedBox(height: 16),

              // Storage Card with better design
              _buildStorageCard(context, storageUsedStr, storageLimitStr,
                  progress, lastStorageSync),
              const SizedBox(height: 20),

              // Quick Actions
              if (!isViewer) ...[
                _buildQuickActions(context),
                const SizedBox(height: 20),
              ],

              _buildSectionTitle(context, 'Vault Spaces'),
              const SizedBox(height: 10),
              _buildTierCard(
                context,
                title: 'Shared',
                subtitle: 'Family categories + member-wise records',
                icon: Icons.groups_rounded,
                color: const Color(0xFF0EA5E9),
                onTap: () => _openCategory('Shared'),
                documentCount: _getDocCountByCategory(documents, 'Shared'),
              ),
              const SizedBox(height: 10),
              _buildTierCard(
                context,
                title: 'Personal',
                subtitle: 'Your own learning, career and business docs',
                icon: Icons.person_rounded,
                color: const Color(0xFF10B981),
                onTap: () => _openCategory('Personal'),
                documentCount: _getDocCountByCategory(documents, 'Personal'),
              ),
              const SizedBox(height: 10),
              _buildTierCard(
                context,
                title: 'Private',
                subtitle: 'Sensitive credentials and confidential records',
                icon: Icons.lock_rounded,
                color: const Color(0xFFF97316),
                onTap: () => _openCategory('Private'),
                documentCount: _getDocCountByCategory(documents, 'Private'),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          isViewer ? null : _buildBottomBar(context, surface, border),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLoading, bool isAdmin,
      int pendingSyncJobs, int failedSyncJobs) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vault',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Secure family document center',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => ref.read(documentProvider.notifier).loadDocuments(),
          icon: AnimatedRotation(
            turns: isLoading ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: Icon(isLoading ? Icons.sync : Icons.refresh_rounded),
          ),
        ),
        if (pendingSyncJobs > 0 || failedSyncJobs > 0)
          IconButton(
            onPressed: () =>
                ref.read(documentProvider.notifier).syncPendingJobs(),
            icon: Icon(
              failedSyncJobs > 0
                  ? Icons.error_outline_rounded
                  : Icons.cloud_sync_rounded,
              color: failedSyncJobs > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF0EA5E9),
            ),
            tooltip: 'Sync now',
          ),
        if (isAdmin)
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.adminEngineDashboard),
            icon:
                const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1)),
            tooltip: 'Engine Dashboard',
          ),
      ],
    );
  }

  Widget _buildSyncBanner(
      BuildContext context, int pendingSyncJobs, int failedSyncJobs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFailures = failedSyncJobs > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasFailures
            ? (isDark ? const Color(0xFF3F1515) : const Color(0xFFFEE2E2))
            : (isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              (hasFailures ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9))
                  .withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (hasFailures
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF0EA5E9))
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasFailures
                  ? Icons.error_outline_rounded
                  : Icons.cloud_upload_rounded,
              color: hasFailures
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF0284C7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFailures
                      ? '$failedSyncJobs sync job${failedSyncJobs == 1 ? '' : 's'} need attention'
                      : '$pendingSyncJobs pending sync job${pendingSyncJobs == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasFailures
                      ? 'Some offline changes have retried several times and now need a manual sync attempt.'
                      : 'Changes made offline will upload when connection is available.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (hasFailures)
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () => _retryFailedSyncJobs(),
                  child: const Text('Retry failed'),
                ),
                TextButton(
                  onPressed: () => _clearFailedSyncJobs(),
                  child: const Text('Clear'),
                ),
              ],
            )
          else
            TextButton(
              onPressed: () =>
                  ref.read(documentProvider.notifier).syncPendingJobs(),
              child: const Text('Sync now'),
            ),
        ],
      ),
    );
  }

  Future<void> _retryFailedSyncJobs() async {
    try {
      await ref.read(documentProvider.notifier).retryFailedSyncJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retrying failed sync jobs')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to retry sync jobs: $e')),
      );
    }
  }

  Future<void> _clearFailedSyncJobs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Failed Sync Jobs'),
        content: const Text(
          'This will remove failed sync jobs from this device. Failed offline uploads will also remove their local pending copies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(documentProvider.notifier).clearFailedSyncJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed sync jobs cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear sync jobs: $e')),
      );
    }
  }

  Widget _buildStatsRow(BuildContext context, List documents) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.description_outlined,
            label: 'Total Files',
            value: documents.length.toString(),
            color: const Color(0xFF0EA5E9),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.folder_open_rounded,
            label: 'Folders',
            value: '22', // Assuming custom folders or categories
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Quick Actions'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.cloud_upload_rounded,
                label: 'Upload',
                color: const Color(0xFF0EA5E9),
                onTap: () async {
                  await Navigator.pushNamed(context, AppRoutes.addDocument);
                  ref.read(documentProvider.notifier).loadDocuments();
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.document_scanner_rounded,
                label: 'Scan',
                color: const Color(0xFF10B981),
                onTap: () async {
                  await Navigator.pushNamed(context, AppRoutes.scanner);
                  ref.read(documentProvider.notifier).loadDocuments();
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.create_new_folder_rounded,
                label: 'Organize',
                color: const Color(0xFFF97316),
                onTap: () => Navigator.pushNamed(context, AppRoutes.documents,
                    arguments: {'category': 'Shared'}),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context, String used, String limit,
      double progress, DateTime? lastSync) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAlmostFull = progress > 0.8;

    // Format last sync time
    String lastSyncText = 'Never synced';
    if (lastSync != null) {
      final now = DateTime.now();
      final diff = now.difference(lastSync);
      if (diff.inSeconds < 60) {
        lastSyncText = 'Just now';
      } else if (diff.inMinutes < 60) {
        lastSyncText = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        lastSyncText = '${diff.inHours}h ago';
      } else {
        lastSyncText = '${diff.inDays}d ago';
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        gradient: LinearGradient(
          colors: isDark
              ? isAlmostFull
                  ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]
                  : [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : isAlmostFull
                  ? [const Color(0xFFFEE2E2), const Color(0xFFFECDD3)]
                  : [const Color(0xFFE0F2FE), const Color(0xFFECFEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isAlmostFull
              ? Colors.red.withValues(alpha: 0.3)
              : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: isAlmostFull
                ? Colors.red.withValues(alpha: 0.1)
                : AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 12,
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
                  color: isAlmostFull
                      ? Colors.red.withValues(alpha: 0.2)
                      : const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAlmostFull ? Icons.warning_rounded : Icons.storage_rounded,
                  color: isAlmostFull ? Colors.red : const Color(0xFF0284C7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage Usage',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAlmostFull ? 'Storage almost full!' : 'Available space',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isAlmostFull
                                ? Colors.red
                                : AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color:
                          isAlmostFull ? Colors.red : const Color(0xFF0284C7),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$used of $limit used',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                lastSyncText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: progress,
                  backgroundColor: Colors.black.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAlmostFull ? Colors.red : const Color(0xFF0284C7),
                  ),
                ),
              ),
              // Animated shine effect
              if (!isAlmostFull)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildTierCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int documentCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(width: 8),
                      if (documentCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            documentCount.toString(),
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Color surface, Color border) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.addDocument);
                  ref.read(documentProvider.notifier).loadDocuments();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Upload Document'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            width: 52,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.scanner);
                ref.read(documentProvider.notifier).loadDocuments();
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
              child: const Icon(Icons.document_scanner_rounded),
            ),
          ),
        ],
      ),
    );
  }

  int _getDocCountByCategory(List documents, String category) {
    return documents.where((doc) => doc.category == category).length;
  }

  void _openCategory(String category) {
    Navigator.pushNamed(context, AppRoutes.documents,
        arguments: {'category': category});
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
