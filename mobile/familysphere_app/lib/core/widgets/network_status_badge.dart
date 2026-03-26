import 'package:familysphere_app/core/providers/network_status_provider.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkStatusBadge extends ConsumerWidget {
  final bool compact;

  const NetworkStatusBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStatus = ref.watch(networkStatusProvider);
    final pendingSyncJobs =
        ref.watch(documentProvider.select((s) => s.pendingSyncJobs));
    final failedSyncJobs =
        ref.watch(documentProvider.select((s) => s.failedSyncJobs));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final _BadgeVisual visual;
    if (networkStatus == NetworkStatus.offline) {
      visual = _BadgeVisual(
        label: 'Offline',
        icon: Icons.cloud_off_rounded,
        background: isDark ? const Color(0xFF1E232A) : const Color(0xFFF3F4F6),
        foreground: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
      );
    } else if (pendingSyncJobs > 0) {
      visual = _BadgeVisual(
        label: failedSyncJobs > 0 ? 'Sync issue' : 'Syncing',
        icon: failedSyncJobs > 0
            ? Icons.sync_problem_rounded
            : Icons.cloud_sync_rounded,
        background: isDark ? const Color(0xFF1E232A) : const Color(0xFFF3F4F6),
        foreground: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
      );
    } else if (networkStatus == NetworkStatus.online) {
      visual = _BadgeVisual(
        label: 'Online',
        icon: Icons.cloud_done_rounded,
        background: isDark ? const Color(0xFF1E232A) : const Color(0xFFF3F4F6),
        foreground: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
      );
    } else {
      visual = _BadgeVisual(
        label: 'Checking',
        icon: Icons.wifi_tethering_rounded,
        background:
            isDark ? AppTheme.darkSurfaceVariant : const Color(0xFFE5E7EB),
        foreground:
            isDark ? AppTheme.darkTextSecondary : const Color(0xFF374151),
      );
    }

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: visual.background.withValues(alpha: isDark ? 0.92 : 1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visual.icon, size: compact ? 12 : 14, color: visual.foreground),
            SizedBox(width: compact ? 5 : 6),
            Text(
              pendingSyncJobs > 0 &&
                      networkStatus != NetworkStatus.offline &&
                      failedSyncJobs == 0
                  ? '${visual.label} ($pendingSyncJobs)'
                  : visual.label,
              style: TextStyle(
                color: visual.foreground,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeVisual {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _BadgeVisual({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });
}
