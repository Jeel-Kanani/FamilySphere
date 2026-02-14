import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/image_to_pdf_provider.dart';
import 'package:familysphere_app/features/lab/presentation/widgets/merge_result_sheet.dart';
import 'package:familysphere_app/features/lab/domain/services/image_to_pdf_service.dart';

/// Image to PDF Screen — fully wired to [imageToPdfProvider].
class ImageToPdfScreen extends ConsumerStatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  ConsumerState<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends ConsumerState<ImageToPdfScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  late final TextEditingController _outputNameController;

  @override
  void initState() {
    super.initState();
    _outputNameController = TextEditingController(text: 'images_to_pdf.pdf');
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(imageToPdfProvider);
    final notifier = ref.read(imageToPdfProvider.notifier);

    // Listen for status changes to show result sheets
    ref.listen<ImageToPdfState>(imageToPdfProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == ImageToPdfStatus.success &&
            next.outputFilePath != null) {
          MergeResultSheet.showSuccess(
            context,
            outputFilePath: next.outputFilePath!,
            outputSizeBytes: next.outputSizeBytes ?? 0,
            onDone: () => notifier.reset(),
            successTitle: 'PDF Created!',
          );
        } else if (next.status == ImageToPdfStatus.error &&
            next.errorMessage != null) {
          MergeResultSheet.showError(
            context,
            errorMessage: next.errorMessage!,
            onRetry: () {
              notifier.dismissError();
              notifier.startConversion();
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
          'Image to PDF',
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
                      if (state.selectedImages.isEmpty)
                        _buildEmptyState(isDark)
                      else ...[
                        _buildImagesList(isDark, state),
                        _buildOutputSettings(isDark, state),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Progress overlay
          if (state.isProcessing && state.status != ImageToPdfStatus.picking)
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
            // Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Convert Images into a PDF',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select images, arrange order, and create a PDF offline. Your files never leave your device.',
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

  // ─── ADD IMAGES BUTTON ────────────────────────────────────────────────────

  Widget _buildAddButton(bool isDark, ImageToPdfState state) {
    final isAtLimit =
        state.selectedImages.length >= ImageToPdfService.maxImages;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: state.isProcessing || isAtLimit
              ? null
              : () => ref.read(imageToPdfProvider.notifier).pickImages(),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : _cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: isAtLimit
                    ? (isDark
                        ? AppTheme.darkBorder
                        : const Color(0xFFE2E8F0))
                    : _primaryBlue.withValues(alpha: 0.4),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              children: [
                // Icon circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isAtLimit
                        ? (isDark
                            ? AppTheme.darkBorder
                            : const Color(0xFFE2E8F0))
                        : _primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_rounded,
                    color: isAtLimit
                        ? (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textTertiary)
                        : _primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isAtLimit
                      ? 'Maximum ${ImageToPdfService.maxImages} images reached'
                      : '+ Add Images',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isAtLimit
                            ? (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textTertiary)
                            : _primaryBlue,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'JPEG, PNG OR WEBP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textTertiary,
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
                Icons.collections_rounded,
                size: 36,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No images selected',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "+ Add Images" to get started',
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

  // ─── SELECTED IMAGES LIST ────────────────────────────────────────────────

  Widget _buildImagesList(bool isDark, ImageToPdfState state) {
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
                'Selected Images',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${state.selectedImages.length} IMAGE${state.selectedImages.length != 1 ? 'S' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _primaryBlue,
                        letterSpacing: 0.5,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Drag hint
          Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Drag images to change page order',
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
              ref
                  .read(imageToPdfProvider.notifier)
                  .reorderImages(oldIndex, newIndex);
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
            itemCount: state.selectedImages.length,
            itemBuilder: (context, index) {
              final image = state.selectedImages[index];
              return _buildImageItem(
                key: ValueKey(image.path),
                image: image,
                index: index,
                isDark: isDark,
              );
            },
          ),

          // Total size
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
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
          ),
        ],
      ),
    );
  }

  Widget _buildImageItem({
    required Key key,
    required SelectedImageFile image,
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
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Image.file(
                  File(image.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDark
                          ? AppTheme.darkBorder
                          : const Color(0xFFE2E8F0),
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 24,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textTertiary,
                      ),
                    );
                  },
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
                    image.name,
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
                    image.sizeLabel,
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
                  ref.read(imageToPdfProvider.notifier).removeImage(index),
              splashRadius: 20,
              tooltip: 'Remove image',
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

  Widget _buildOutputSettings(bool isDark, ImageToPdfState state) {
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
            // Section title
            Row(
              children: [
                Icon(Icons.settings_rounded, color: _primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Output Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Output PDF Name
            Text(
              'Output PDF Name',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackground
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color:
                      isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _outputNameController,
                onChanged: (value) =>
                    ref.read(imageToPdfProvider.notifier).setOutputName(value),
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
            const SizedBox(height: 20),

            // Page Size & Orientation row
            Row(
              children: [
                // Page Size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page Size',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkBackground
                              : const Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PdfPageSize>(
                            value: state.pageSize,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusM),
                            dropdownColor: isDark
                                ? AppTheme.darkSurface
                                : Colors.white,
                            icon: Icon(
                              Icons.expand_more_rounded,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textTertiary,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                            items: PdfPageSize.values
                                .map((size) => DropdownMenuItem(
                                      value: size,
                                      child: Text(
                                        size.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                    .read(imageToPdfProvider.notifier)
                                    .setPageSize(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Orientation
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orientation',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkBackground
                              : const Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PdfOrientation>(
                            value: state.orientation,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusM),
                            dropdownColor: isDark
                                ? AppTheme.darkSurface
                                : Colors.white,
                            icon: Icon(
                              Icons.expand_more_rounded,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textTertiary,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                            items: PdfOrientation.values
                                .map((orient) => DropdownMenuItem(
                                      value: orient,
                                      child: Text(orient.label),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                    .read(imageToPdfProvider.notifier)
                                    .setOrientation(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Quality tip
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: _primaryBlue.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: _primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: Use "Auto" for best quality. It preserves original image resolution without rescaling.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : const Color(0xFF475569),
                            height: 1.4,
                          ),
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

  // ─── PROGRESS OVERLAY ─────────────────────────────────────────────────────

  Widget _buildProgressOverlay(bool isDark, ImageToPdfState state) {
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

              // Image count
              Text(
                'Converting ${ref.read(imageToPdfProvider).selectedImages.length} images…',
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
                    ref.read(imageToPdfProvider.notifier).cancelConversion(),
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
    ImageToPdfState state,
  ) {
    final canConvert = state.canConvert;

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
                onPressed: canConvert
                    ? () => ref
                        .read(imageToPdfProvider.notifier)
                        .startConversion()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  disabledBackgroundColor: isDark
                      ? _primaryBlue.withValues(alpha: 0.3)
                      : _primaryBlue.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  disabledForegroundColor:
                      Colors.white.withValues(alpha: 0.6),
                  elevation: canConvert ? 4 : 0,
                  shadowColor: _primaryBlue.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'CREATE PDF',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: canConvert
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
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
