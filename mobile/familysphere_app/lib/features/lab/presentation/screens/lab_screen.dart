import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/lab/presentation/providers/lab_recent_files_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/features/vault/document_preview_screen.dart';

class LabScreen extends ConsumerStatefulWidget {
  const LabScreen({super.key});

  @override
  ConsumerState<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends ConsumerState<LabScreen> {
  // Colors
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _pageBackground = Color(0xFFF6F7F8);
  static const Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(labRecentFilesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labRecentFiles = ref.watch(labRecentFilesProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : _pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(context, isDark),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    _buildSearchBar(context, isDark),

                    // Recent Files (from Lab tool outputs)
                    _buildRecentFilesSection(context, isDark, labRecentFiles),

                    // PDF Lab
                    _buildPdfLabSection(context, isDark),

                    // Image Lab
                    _buildImageLabSection(context, isDark),

                    // Document Tools
                    _buildDocumentToolsSection(context, isDark),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkBackground.withValues(alpha: 0.95)
            : _pageBackground.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            context,
            icon: Icons.menu_rounded,
            isDark: isDark,
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          Text(
            'LAB',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
          _buildCircleButton(
            context,
            icon: Icons.settings_rounded,
            isDark: isDark,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(
    BuildContext context, {
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? AppTheme.darkSurface.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
          child: Icon(
            icon,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ─── SEARCH BAR ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : _cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search tools or files',
            hintStyle: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ─── RECENT FILES (DYNAMIC) ───────────────────────────────────────────────────

  /// Returns the appropriate icon and color for a given file type
  _FileIconInfo _getFileIconInfo(String fileType, String title) {
    final type = fileType.toLowerCase();
    final lowerTitle = title.toLowerCase();

    if (type == 'pdf' || lowerTitle.endsWith('.pdf')) {
      return _FileIconInfo(Icons.picture_as_pdf_rounded, const Color(0xFFEF4444));
    } else if (type == 'image' ||
        lowerTitle.endsWith('.jpg') ||
        lowerTitle.endsWith('.jpeg') ||
        lowerTitle.endsWith('.png') ||
        lowerTitle.endsWith('.webp')) {
      return _FileIconInfo(Icons.image_rounded, const Color(0xFF3B82F6));
    } else if (type == 'doc' ||
        type == 'docx' ||
        lowerTitle.endsWith('.docx') ||
        lowerTitle.endsWith('.doc')) {
      return _FileIconInfo(Icons.description_rounded, const Color(0xFF3B82F6));
    } else if (type == 'zip' ||
        type == 'rar' ||
        lowerTitle.endsWith('.zip') ||
        lowerTitle.endsWith('.rar')) {
      return _FileIconInfo(Icons.folder_zip_rounded, const Color(0xFFF97316));
    } else if (type == 'xls' ||
        type == 'xlsx' ||
        lowerTitle.endsWith('.xlsx') ||
        lowerTitle.endsWith('.xls')) {
      return _FileIconInfo(Icons.table_chart_rounded, const Color(0xFF10B981));
    } else if (type == 'ppt' ||
        type == 'pptx' ||
        lowerTitle.endsWith('.pptx') ||
        lowerTitle.endsWith('.ppt')) {
      return _FileIconInfo(Icons.slideshow_rounded, const Color(0xFFF97316));
    } else {
      return _FileIconInfo(Icons.insert_drive_file_rounded, const Color(0xFF64748B));
    }
  }

  /// Whether the file is an image that can show a thumbnail
  bool _isImageFile(String fileType, String title) {
    final type = fileType.toLowerCase();
    final lowerTitle = title.toLowerCase();
    return type == 'image' ||
        lowerTitle.endsWith('.jpg') ||
        lowerTitle.endsWith('.jpeg') ||
        lowerTitle.endsWith('.png') ||
        lowerTitle.endsWith('.webp');
  }

  Widget _buildRecentFilesSection(
    BuildContext context,
    bool isDark,
    List<LabRecentFile> recentFiles,
  ) {
    final displayFiles = recentFiles.take(10).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Recent Files',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
            ),
          ),
          const SizedBox(height: 12),

          // Empty state
          if (displayFiles.isEmpty)
            _buildEmptyRecentFiles(context, isDark)
          // Files list
          else
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: displayFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return _buildLabRecentFileCard(context, displayFiles[index], isDark);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Empty state widget when no recent files exist
  Widget _buildEmptyRecentFiles(BuildContext context, bool isDark) {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : _cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              'No recent files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Files from Lab tools will appear here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabRecentFileCard(
    BuildContext context,
    LabRecentFile file,
    bool isDark,
  ) {
    // Determine icon based on file extension
    final ext = file.fileName.split('.').last.toLowerCase();
    final iconData = ext == 'pdf'
        ? Icons.picture_as_pdf_rounded
        : ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp'
            ? Icons.image_rounded
            : Icons.insert_drive_file_rounded;
    final iconColor = ext == 'pdf'
        ? const Color(0xFFEF4444)
        : const Color(0xFF2563EB);

    // Time ago label
    final diff = DateTime.now().difference(file.createdAt);
    final timeLabel = diff.inMinutes < 1
        ? 'Just now'
        : diff.inMinutes < 60
            ? '${diff.inMinutes}m ago'
            : diff.inHours < 24
                ? '${diff.inHours}h ago'
                : diff.inDays < 7
                    ? '${diff.inDays}d ago'
                    : '${file.createdAt.day}/${file.createdAt.month}/${file.createdAt.year}';

    return GestureDetector(
      onTap: () {
        // Open in the in-app PDF viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(documentUrl: file.filePath),
          ),
        );
      },
      child: SizedBox(
        width: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area with icon and tool badge
            Container(
              height: 110,
              width: 136,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  width: 0.5,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      iconData,
                      size: 40,
                      color: iconColor,
                    ),
                  ),
                  // Tool badge (top-right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        file.toolLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // File name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                file.fileName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            // Size + time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${LabFileManager.formatFileSize(file.sizeBytes)} • $timeLabel',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PDF LAB ──────────────────────────────────────────────────────────────────

  Widget _buildPdfLabSection(BuildContext context, bool isDark) {
    final pdfTools = [
      _LabToolData(icon: Icons.call_merge_rounded, label: 'Merge PDF', route: '/merge-pdf'),
      _LabToolData(icon: Icons.call_split_rounded, label: 'Split PDF', route: '/split-pdf'),
      _LabToolData(icon: Icons.compress_rounded, label: 'Compress'),
      _LabToolData(icon: Icons.text_snippet_rounded, label: 'To Word'),
      _LabToolData(icon: Icons.lock_rounded, label: 'Protect'),
      _LabToolData(icon: Icons.rotate_right_rounded, label: 'Rotate'),
    ];

    return _buildToolGridSection(
      context,
      title: 'PDF LAB',
      titleIcon: Icons.picture_as_pdf_rounded,
      tools: pdfTools,
      isDark: isDark,
    );
  }

  // ─── IMAGE LAB ────────────────────────────────────────────────────────────────

  Widget _buildImageLabSection(BuildContext context, bool isDark) {
    final imageTools = [
      _LabToolData(icon: Icons.photo_size_select_small_rounded, label: 'Compress'),
      _LabToolData(icon: Icons.aspect_ratio_rounded, label: 'Resize'),
      _LabToolData(icon: Icons.crop_rounded, label: 'Crop Image'),
      _LabToolData(icon: Icons.transform_rounded, label: 'Convert'),
      _LabToolData(icon: Icons.picture_as_pdf_rounded, label: 'Image to PDF', route: '/image-process'),
      _LabToolData(icon: Icons.auto_fix_high_rounded, label: 'BG Remover'),
    ];

    return _buildToolGridSection(
      context,
      title: 'IMAGE LAB',
      titleIcon: Icons.image_rounded,
      tools: imageTools,
      isDark: isDark,
    );
  }

  // ─── TOOL GRID (reusable for PDF & Image Lab) ─────────────────────────────

  Widget _buildToolGridSection(
    BuildContext context, {
    required String title,
    required IconData titleIcon,
    required List<_LabToolData> tools,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(titleIcon, color: _primaryBlue, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2-column grid
          GridView.builder(
            itemCount: tools.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              return _buildToolButton(context, tools[index], isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context,
    _LabToolData tool,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (tool.route != null) {
            Navigator.pushNamed(context, tool.route!);
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Icon(
                tool.icon,
                color: _primaryBlue,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tool.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── DOCUMENT TOOLS ───────────────────────────────────────────────────────────

  Widget _buildDocumentToolsSection(BuildContext context, bool isDark) {
    final docTools = [
      _LabToolData(icon: Icons.swap_horiz_rounded, label: 'File Converter'),
      _LabToolData(icon: Icons.folder_zip_rounded, label: 'Zip / Unzip'),
      _LabToolData(icon: Icons.edit_square, label: 'Rename Files'),
      _LabToolData(icon: Icons.visibility_rounded, label: 'Preview & Share'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOCUMENT TOOLS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          ...docTools.map(
            (tool) => _buildDocumentToolItem(context, tool, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentToolItem(
    BuildContext context,
    _LabToolData tool,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: Navigate to tool screen
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                Icon(tool.icon, color: _primaryBlue, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    tool.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────────────────

class _FileIconInfo {
  final IconData icon;
  final Color color;
  const _FileIconInfo(this.icon, this.color);
}

class _LabToolData {
  final IconData icon;
  final String label;
  final String? route;

  const _LabToolData({
    required this.icon,
    required this.label,
    this.route,
  });
}
