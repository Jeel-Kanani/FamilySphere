import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/merge_pdf_provider.dart';
import 'package:familysphere_app/features/lab/presentation/widgets/merge_result_sheet.dart';

/// Merge PDF Screen — fully wired to [mergePdfProvider].
class MergePdfScreen extends ConsumerStatefulWidget {
  const MergePdfScreen({super.key});

  @override
  ConsumerState<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends ConsumerState<MergePdfScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  late final TextEditingController _outputNameController;

  @override
  void initState() {
    super.initState();
    _outputNameController = TextEditingController(text: 'merged.pdf');
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(mergePdfProvider);
    final notifier = ref.read(mergePdfProvider.notifier);

    // Listen for status changes to show result sheets
    ref.listen<MergePdfState>(mergePdfProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == MergeStatus.success && next.outputFilePath != null) {
          MergeResultSheet.showSuccess(
            context,
            outputFilePath: next.outputFilePath!,
            outputSizeBytes: next.outputSizeBytes ?? 0,
            onDone: () => notifier.reset(),
          );
        } else if (next.status == MergeStatus.error &&
            next.errorMessage != null) {
          MergeResultSheet.showError(
            context,
            errorMessage: next.errorMessage!,
            onRetry: () {
              notifier.dismissError();
              notifier.startMerge();
            },
            onDone: () => notifier.dismissError(),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Merge PDF',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.science_rounded, color: _primaryBlue, size: 24),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionCard(isDark),
                      _buildAddButton(isDark, state),
                      if (state.selectedFiles.isEmpty)
                        _buildEmptyState(isDark)
                      else ...[
                        _buildFilesList(isDark, state),
                        _buildOutputSettings(isDark),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Progress overlay
          if (state.isProcessing && state.status != MergeStatus.picking)
            _buildProgressOverlay(isDark, state),
        ],
      ),
      bottomNavigationBar: _buildBottomButton(context, isDark, state),
    );
  }

  // ─── INSTRUCTION CARD ─────────────────────────────────────────────────────

  Widget _buildInstructionCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? _primaryBlue.withValues(alpha: 0.15)
              : _primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                color: _primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select two or more PDF files to merge',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your original files are never changed. All processing happens locally on your device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADD BUTTON ───────────────────────────────────────────────────────────

  Widget _buildAddButton(bool isDark, MergePdfState state) {
    final isAtLimit = state.selectedFiles.length >= 10;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: state.isProcessing || isAtLimit
              ? null
              : () => ref.read(mergePdfProvider.notifier).pickFiles(),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : _cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: isAtLimit
                    ? (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))
                    : _primaryBlue.withValues(alpha: 0.4),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_rounded,
                  color: isAtLimit
                      ? (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textTertiary)
                      : _primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isAtLimit ? 'Maximum 10 files reached' : 'Add PDF Files',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isAtLimit
                            ? (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textTertiary)
                            : _primaryBlue,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── EMPTY STATE ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface
                    : _primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                size: 36,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No files selected',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Add PDF Files" to get started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SELECTED FILES LIST ──────────────────────────────────────────────────

  Widget _buildFilesList(bool isDark, MergePdfState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SELECTED FILES (${state.selectedFiles.length})',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textTertiary,
                    ),
              ),
              Text(
                'Order from Top to Bottom',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textTertiary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reorderable list
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              ref.read(mergePdfProvider.notifier).reorderFiles(oldIndex, newIndex);
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevation = Tween<double>(begin: 0, end: 6)
                      .animate(animation)
                      .value;
                  return Material(
                    elevation: elevation,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    color: Colors.transparent,
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemCount: state.selectedFiles.length,
            itemBuilder: (context, index) {
              final file = state.selectedFiles[index];
              return _buildFileItem(
                key: ValueKey(file.path),
                file: file,
                index: index,
                isDark: isDark,
              );
            },
          ),

          // Total size + Drag hint
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                // Total size
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 14,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Total: ${state.totalSizeLabel}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Drag hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.drag_handle_rounded,
                      size: 18,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Drag files to change merge order',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem({
    required Key key,
    required SelectedPdfFile file,
    required int index,
    required bool isDark,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : _cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // PDF icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: const Center(
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${file.sizeLabel} • ${file.dateLabel}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textTertiary,
                        ),
                  ),
                ],
              ),
            ),

            // Remove button
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textTertiary,
              ),
              onPressed: () =>
                  ref.read(mergePdfProvider.notifier).removeFile(index),
              splashRadius: 20,
              tooltip: 'Remove file',
            ),

            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 22,
                  color: isDark
                      ? AppTheme.darkTextSecondary.withValues(alpha: 0.5)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── OUTPUT SETTINGS ──────────────────────────────────────────────────────

  Widget _buildOutputSettings(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : _cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Output File Name',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackground
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _outputNameController,
                onChanged: (value) =>
                    ref.read(mergePdfProvider.notifier).setOutputName(value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.save_rounded,
                  size: 16,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap Save after merge to save to Downloads',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textTertiary,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── PROGRESS OVERLAY ─────────────────────────────────────────────────────

  Widget _buildProgressOverlay(bool isDark, MergePdfState state) {
    return Container(
      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : _cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: state.progress > 0.1 ? state.progress : null,
                  strokeWidth: 4,
                  color: _primaryBlue,
                  backgroundColor: isDark
                      ? AppTheme.darkBorder
                      : const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 20),

              // Status message
              Text(
                state.progressMessage.isNotEmpty
                    ? state.progressMessage
                    : 'Processing...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // File count
              Text(
                'Merging ${ref.read(mergePdfProvider).selectedFiles.length} PDFs…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),

              // Cancel button
              TextButton(
                onPressed: () =>
                    ref.read(mergePdfProvider.notifier).cancelMerge(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM BUTTON ────────────────────────────────────────────────────────

  Widget _buildBottomButton(
    BuildContext context,
    bool isDark,
    MergePdfState state,
  ) {
    final canMerge = state.canMerge;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkBackground.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canMerge
                    ? () => ref.read(mergePdfProvider.notifier).startMerge()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  disabledBackgroundColor: isDark
                      ? _primaryBlue.withValues(alpha: 0.3)
                      : _primaryBlue.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  disabledForegroundColor:
                      Colors.white.withValues(alpha: 0.6),
                  elevation: canMerge ? 4 : 0,
                  shadowColor: _primaryBlue.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.merge_type_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'MERGE PDF',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: canMerge
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 1.0,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'OFFLINE READY • SECURE PROCESSING',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textTertiary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
