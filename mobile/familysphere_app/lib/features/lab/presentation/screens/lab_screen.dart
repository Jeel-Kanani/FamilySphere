import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';

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
      final docState = ref.read(documentProvider);
      if (!docState.isLoading && docState.documents.isEmpty) {
        ref.read(documentProvider.notifier).loadDocuments();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final documentsState = ref.watch(documentProvider);

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

                    // Recent Files (dynamic from documentProvider)
                    _buildRecentFilesSection(context, isDark, documentsState),

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
    DocumentState documentsState,
  ) {
    // Sort documents by upload date (most recent first) and take up to 10
    final recentDocs = List<DocumentEntity>.from(documentsState.documents)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    final displayDocs = recentDocs.take(10).toList();

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

          // Loading state
          if (documentsState.isLoading && documentsState.documents.isEmpty)
            const SizedBox(
              height: 170,
              child: Center(child: CircularProgressIndicator()),
            )
          // Empty state
          else if (displayDocs.isEmpty)
            _buildEmptyRecentFiles(context, isDark)
          // Documents list
          else
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: displayDocs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return _buildRecentFileCard(context, displayDocs[index], isDark);
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
              'Your recently uploaded files will appear here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFileCard(
    BuildContext context,
    DocumentEntity doc,
    bool isDark,
  ) {
    final iconInfo = _getFileIconInfo(doc.fileType, doc.title);
    final isImage = _isImageFile(doc.fileType, doc.title);

    return GestureDetector(
      onTap: () {
        // Navigate to document viewer
        Navigator.pushNamed(context, '/document-viewer', arguments: doc);
      },
      child: SizedBox(
        width: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              height: 130,
              width: 136,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                child: isImage && doc.fileUrl.isNotEmpty
                    ? Image.network(
                        doc.fileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            iconInfo.icon,
                            size: 40,
                            color: iconInfo.color,
                          ),
                        ),
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: _primaryBlue,
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          iconInfo.icon,
                          size: 40,
                          color: iconInfo.color,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // File name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                doc.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
      _LabToolData(icon: Icons.call_merge_rounded, label: 'Merge PDF'),
      _LabToolData(icon: Icons.call_split_rounded, label: 'Split PDF'),
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
      _LabToolData(icon: Icons.picture_as_pdf_rounded, label: 'Image to PDF'),
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
          // TODO: Navigate to tool screen
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

  const _LabToolData({
    required this.icon,
    required this.label,
  });
}
