import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/services/notification_service.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';

/// Reusable bottom sheet for showing Lab tool results (success or error).
class MergeResultSheet extends StatelessWidget {
  const MergeResultSheet._({
    required this.isSuccess,
    this.outputFilePath,
    this.outputSizeBytes,
    this.outputFileName,
    this.successTitle,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
    this.onDone,
  });

  final bool isSuccess;
  final String? outputFilePath;
  final int? outputSizeBytes;
  final String? outputFileName;
  final String? successTitle;
  final String? errorTitle;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onDone;

  /// Shows a success result sheet.
  static Future<void> showSuccess(
    BuildContext context, {
    required String outputFilePath,
    required int outputSizeBytes,
    required VoidCallback onDone,
    String? successTitle,
  }) {
    final fileName = outputFilePath.split(Platform.pathSeparator).last;
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => MergeResultSheet._(
        isSuccess: true,
        outputFilePath: outputFilePath,
        outputSizeBytes: outputSizeBytes,
        outputFileName: fileName,
        successTitle: successTitle,
        onDone: onDone,
      ),
    );
  }

  /// Shows an error result sheet.
  static Future<void> showError(
    BuildContext context, {
    required String errorMessage,
    required VoidCallback onRetry,
    required VoidCallback onDone,
    String? errorTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MergeResultSheet._(
        isSuccess: false,
        errorMessage: errorMessage,
        errorTitle: errorTitle,
        onRetry: onRetry,
        onDone: onDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBorder
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              if (isSuccess) _buildSuccessContent(context, isDark)
              else _buildErrorContent(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessContent(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          successTitle ?? 'Merge Completed!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 8),

        // File info
        Text(
          '${outputFileName ?? 'merged.pdf'} • ${LabFileManager.formatFileSize(outputSizeBytes ?? 0)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 6),

        // Privacy note
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_rounded,
              size: 14,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              'Processed securely on your device',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textTertiary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Action buttons: Download | Share | Done
        Row(
          children: [
            // Download to public Downloads
            Expanded(
              child: _DownloadButton(
                filePath: outputFilePath,
                fileName: outputFileName,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),

            // Share
            Expanded(
              child: _ActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                isDark: isDark,
                outlined: true,
                onTap: () {
                  if (outputFilePath != null) {
                    Share.shareXFiles([XFile(outputFilePath!)]);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // Done
            Expanded(
              child: _ActionButton(
                icon: Icons.check_rounded,
                label: 'Done',
                isDark: isDark,
                outlined: false,
                onTap: () {
                  Navigator.pop(context);
                  onDone?.call();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4444),
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          errorTitle ?? 'Couldn\'t Merge Files',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 8),

        // Error message
        Text(
          errorMessage ?? 'An unexpected error occurred.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 8),

        // Safety note
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_rounded,
              size: 14,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              'Your original files are untouched',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textTertiary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Action buttons
        Row(
          children: [
            // Cancel
            Expanded(
              child: _ActionButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                isDark: isDark,
                outlined: true,
                onTap: () {
                  Navigator.pop(context);
                  onDone?.call();
                },
              ),
            ),
            const SizedBox(width: 12),

            // Retry
            Expanded(
              child: _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'Retry',
                isDark: isDark,
                outlined: false,
                onTap: () {
                  Navigator.pop(context);
                  onRetry?.call();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── ACTION BUTTON ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.outlined,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final bool outlined;
  final VoidCallback onTap;

  static const Color _primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                side: BorderSide(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                ),
              ),
            ),
    );
  }
}

// ─── DOWNLOAD BUTTON (stateful — shows "Downloaded ✓" after download) ────────

class _DownloadButton extends StatefulWidget {
  const _DownloadButton({
    required this.filePath,
    required this.fileName,
    required this.isDark,
  });

  final String? filePath;
  final String? fileName;
  final bool isDark;

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _downloading = false;
  bool _downloaded = false;

  Future<void> _download() async {
    if (widget.filePath == null || _downloading || _downloaded) return;
    setState(() => _downloading = true);

    try {
      // Save to public Downloads folder using native Android MediaStore
      final fileManager = LabFileManager();
      final downloadedPath = await fileManager.saveToDownloads(widget.filePath!, 'Lab');
      
      // Show system notification
      await NotificationService().showDownloadNotification(
        fileName: widget.fileName ?? 'file',
        filePath: downloadedPath,
      );
      
      if (mounted) {
        setState(() { _downloading = false; _downloaded = true; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Downloaded Successfully!', 
                         style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 4),
                Text('Saved to Downloads folder',
                     style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Download Failed', 
                         style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 4),
                Text(e.toString(), style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _downloaded ? null : _download,
        icon: _downloading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _downloaded ? Icons.check_circle_rounded : Icons.download_rounded,
                size: 20,
                color: _downloaded ? const Color(0xFF10B981) : null,
              ),
        label: Text(
          _downloaded ? 'Downloaded' : 'Download',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _downloaded ? const Color(0xFF10B981) : null,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          side: BorderSide(
            color: _downloaded
                ? const Color(0xFF10B981)
                : widget.isDark
                    ? AppTheme.darkBorder
                    : const Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
        ),
      ),
    );
  }
}
