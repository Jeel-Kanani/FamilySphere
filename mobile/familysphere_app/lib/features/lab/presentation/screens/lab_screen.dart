import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/services/notification_service.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:familysphere_app/core/utils/routes.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(labRecentFilesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_LabToolData> get _pdfTools => const [
        _LabToolData(
          id: 'merge_pdf',
          icon: Icons.call_merge_rounded,
          label: 'Merge PDF',
          subtitle: 'Combine many PDFs into one file',
          route: AppRoutes.mergePdf,
        ),
        _LabToolData(
          id: 'split_pdf',
          icon: Icons.call_split_rounded,
          label: 'Split PDF',
          subtitle: 'Extract page ranges into smaller files',
          route: AppRoutes.splitPdf,
        ),
        _LabToolData(
          id: 'compress_pdf',
          icon: Icons.compress_rounded,
          label: 'Compress PDF',
          subtitle: 'Reduce size for easy sharing',
          route: AppRoutes.compressPdf,
        ),
        _LabToolData(
          id: 'pdf_to_text',
          icon: Icons.text_snippet_rounded,
          label: 'PDF to Text',
          subtitle: 'Extract readable text quickly',
          route: AppRoutes.pdfToText,
        ),
        _LabToolData(
          id: 'protect_pdf',
          icon: Icons.lock_rounded,
          label: 'Protect PDF',
          subtitle: 'Add password security',
          route: AppRoutes.protectPdf,
        ),
        _LabToolData(
          id: 'rotate_pdf',
          icon: Icons.rotate_right_rounded,
          label: 'Rotate PDF',
          subtitle: 'Fix page orientation',
          route: AppRoutes.rotatePdf,
        ),
        _LabToolData(
          id: 'unlock_pdf',
          icon: Icons.lock_open_rounded,
          label: 'Unlock PDF',
          subtitle: 'Remove password protection',
          route: AppRoutes.unlockPdf,
        ),
      ];

  List<_LabToolData> get _imageTools => const [
        _LabToolData(
          id: 'image_compress',
          icon: Icons.photo_size_select_small_rounded,
          label: 'Compress Image',
          subtitle: 'Shrink large photos',
          route: AppRoutes.imageCompress,
        ),
        _LabToolData(
          id: 'image_resize',
          icon: Icons.aspect_ratio_rounded,
          label: 'Resize Image',
          subtitle: 'Change image dimensions',
          route: AppRoutes.imageResize,
        ),
        _LabToolData(
          id: 'crop_image',
          icon: Icons.crop_rounded,
          label: 'Crop Image',
          subtitle: 'Trim edges and focus content',
          route: AppRoutes.cropImage,
        ),
        _LabToolData(
          id: 'image_convert',
          icon: Icons.transform_rounded,
          label: 'Convert Image',
          subtitle: 'JPG, PNG and more',
          route: AppRoutes.imageConvert,
        ),
        _LabToolData(
          id: 'image_to_pdf',
          icon: Icons.picture_as_pdf_rounded,
          label: 'Image to PDF',
          subtitle: 'Create PDFs from photos',
          route: AppRoutes.imageProcess,
        ),
        _LabToolData(
          id: 'bg_remover',
          icon: Icons.auto_fix_high_rounded,
          label: 'BG Remover',
          subtitle: 'Cut out subjects fast',
          route: AppRoutes.bgRemover,
        ),
      ];

  List<_LabToolData> get _documentTools => const [
        _LabToolData(
          id: 'file_converter',
          icon: Icons.swap_horiz_rounded,
          label: 'File Converter',
          subtitle: 'Jump into the right conversion tool',
          route: AppRoutes.fileConverter,
        ),
        _LabToolData(
          id: 'zip_unzip',
          icon: Icons.folder_zip_rounded,
          label: 'Zip / Unzip',
          subtitle: 'Bundle or unpack files',
          route: AppRoutes.zipUnzip,
        ),
        _LabToolData(
          id: 'batch_rename',
          icon: Icons.edit_square,
          label: 'Rename Files',
          subtitle: 'Rename many files in one step',
          route: AppRoutes.batchRename,
        ),
        _LabToolData(
          id: 'preview_share',
          icon: Icons.visibility_rounded,
          label: 'Preview & Share',
          subtitle: 'Inspect output before sending',
          route: AppRoutes.previewShare,
        ),
        _LabToolData(
          id: 'scan_document',
          icon: Icons.document_scanner_rounded,
          label: 'Scan Document',
          subtitle: 'Capture paper files into PDF',
          route: AppRoutes.documentCapture,
        ),
      ];

  List<_LabToolData> _filterTools(List<_LabToolData> tools) {
    if (_searchQuery.trim().isEmpty) return tools;
    final needle = _searchQuery.trim().toLowerCase();
    return tools
        .where(
          (tool) =>
              tool.label.toLowerCase().contains(needle) ||
              tool.subtitle.toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labRecentFiles = ref.watch(labRecentFilesProvider);
    final filteredPdfTools = _filterTools(_pdfTools);
    final filteredImageTools = _filterTools(_imageTools);
    final filteredDocumentTools = _filterTools(_documentTools);
    final filteredRecentFiles = _searchQuery.trim().isEmpty
        ? labRecentFiles
        : labRecentFiles
            .where(
              (file) =>
                  file.fileName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  file.toolLabel
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()),
            )
            .toList();

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
                    _buildRecentFilesSection(
                        context, isDark, filteredRecentFiles),

                    // PDF Lab
                    _buildPdfLabSection(context, isDark, filteredPdfTools),

                    // Image Lab
                    _buildImageLabSection(context, isDark, filteredImageTools),

                    // Document Tools
                    _buildDocumentToolsSection(
                      context,
                      isDark,
                      filteredDocumentTools,
                    ),

                    _buildUtilitiesSection(context, isDark, labRecentFiles),

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
            ? AppTheme.darkBackground.withOpacity(0.95)
            : _pageBackground.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _buildCircleButton(
              context,
              icon: Icons.info_outline_rounded,
              isDark: isDark,
              onTap: () => _showLabInfo(context, isDark),
            ),
          ),
          Text(
            'LAB',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _buildCircleButton(
              context,
              icon: Icons.settings_rounded,
              isDark: isDark,
              onTap: () => _showLabSettings(context, isDark),
            ),
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
                ? AppTheme.darkSurface.withOpacity(0.5)
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search tools, workflows, or outputs',
            hintStyle: TextStyle(
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Files',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                  ),
                ),
                Text(
                  '${displayFiles.length} shown',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                ),
                if (displayFiles.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(labRecentFilesProvider.notifier).refresh(),
                    child: const Text('Refresh'),
                  ),
                ],
              ],
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
                  return _buildLabRecentFileCard(
                      context, displayFiles[index], isDark);
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
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              'No recent files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Files from Lab tools will appear here',
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
    final iconColor =
        ext == 'pdf' ? const Color(0xFFEF4444) : const Color(0xFF2563EB);

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
        // Determine if file is image or PDF
        final isImage =
            ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';

        if (isImage) {
          // Open image in image viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ImageViewerScreen(imagePath: file.filePath),
            ),
          );
        } else {
          // Open in PDF viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentPreviewScreen(documentUrl: file.filePath),
            ),
          );
        }
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
                  // Tool badge (top-left)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.12),
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
                  // Three-dot menu (top-right)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white)
                                .withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_vert,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        onSelected: (value) =>
                            _handleFileMenuAction(context, value, file, isDark),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Download'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Share'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Rename'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Details'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'copy_path',
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Copy Path'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_rounded,
                                    size: 18, color: Colors.red),
                                const SizedBox(width: 12),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
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
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
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
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textTertiary,
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

  /// Handles file menu actions (download, share, rename, delete, etc.)
  void _handleFileMenuAction(BuildContext context, String action,
      LabRecentFile file, bool isDark) async {
    switch (action) {
      case 'download':
        await _downloadFile(context, file);
        break;
      case 'share':
        await _shareFile(context, file);
        break;
      case 'rename':
        await _renameFile(context, file, isDark);
        break;
      case 'details':
        _showFileDetails(context, file, isDark);
        break;
      case 'copy_path':
        await _copyFilePath(context, file);
        break;
      case 'delete':
        await _deleteFile(context, file, isDark);
        break;
    }
  }

  /// Downloads file to public Downloads folder
  /// Android 10+ uses Scoped Storage - no permission needed for Downloads
  Future<void> _downloadFile(BuildContext context, LabRecentFile file) async {
    try {
      // Show loading indicator
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Downloading...'),
            ],
          ),
          duration: Duration(hours: 1), // Keep showing until we hide it
        ),
      );

      final sourceFile = File(file.filePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file not found');
      }

      // Use LabFileManager to save to public Downloads
      final fileManager = LabFileManager();
      final downloadedPath =
          await fileManager.saveToDownloads(file.filePath, file.toolLabel);

      final finalFileName = downloadedPath.split(Platform.pathSeparator).last;

      // Show system notification
      await NotificationService().showDownloadNotification(
        fileName: finalFileName,
        filePath: downloadedPath,
      );

      if (!context.mounted) return;
      // Hide loading and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.download_done, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Downloaded Successfully!',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finalFileName,
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved to Downloads folder',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check your file manager',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Download Failed',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                e.toString(),
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  /// Shares file using share_plus
  Future<void> _shareFile(BuildContext context, LabRecentFile file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.filePath)],
        text: file.fileName,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Renames the file
  Future<void> _renameFile(
      BuildContext context, LabRecentFile file, bool isDark) async {
    final controller = TextEditingController(text: file.fileName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text('Rename File',
            style: TextStyle(
                color:
                    isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'New file name',
            labelStyle: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == file.fileName) return;

    try {
      final oldFile = File(file.filePath);
      final directory = oldFile.parent;
      final newPath = '${directory.path}${Platform.pathSeparator}$newName';

      // Check if new file name already exists
      if (await File(newPath).exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A file with this name already exists'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Rename the file
      await oldFile.rename(newPath);

      // Update the recent files entry with new path (keeps it in the list!)
      await ref.read(labRecentFilesProvider.notifier).updateFilePath(
            file.filePath,
            newPath,
          );

      // Show system notification
      await NotificationService().showRenameNotification(
        file.fileName,
        newName,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Renamed to: $newName'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to rename: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Shows file details dialog
  /// Shows file details dialog with download option
  void _showFileDetails(BuildContext context, LabRecentFile file, bool isDark) {
    final ext = file.fileName.split('.').last.toUpperCase();
    final createdDate = file.createdAt.toString().split('.')[0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: _primaryBlue,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'File Details',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('File Name', file.fileName, isDark),
              const Divider(height: 24),
              _buildDetailRow('Type', ext, isDark),
              const Divider(height: 24),
              _buildDetailRow('Size',
                  LabFileManager.formatFileSize(file.sizeBytes), isDark),
              const Divider(height: 24),
              _buildDetailRow('Tool', file.toolLabel, isDark),
              const Divider(height: 24),
              _buildDetailRow('Created', createdDate, isDark),
              const Divider(height: 24),
              _buildDetailRow('Path', file.filePath, isDark, isPath: true),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadFile(context, file);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
            style: TextButton.styleFrom(
              foregroundColor: _primaryBlue,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark,
      {bool isPath = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          maxLines: isPath ? 4 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Copies file path to clipboard
  Future<void> _copyFilePath(BuildContext context, LabRecentFile file) async {
    await Clipboard.setData(ClipboardData(text: file.filePath));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File path copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Deletes the file with confirmation dialog
  /// IMPORTANT: Shows confirmation dialog FIRST, only deletes if user confirms
  Future<void> _deleteFile(
      BuildContext context, LabRecentFile file, bool isDark) async {
    // Step 1: Show confirmation dialog BEFORE deleting anything
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text('Delete File',
                style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${file.fileName}"?\n\nThis action cannot be undone.',
          style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: Text('Delete', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    // Step 2: Only proceed with deletion if user clicked "Delete" button
    if (confirm != true) {
      // User clicked Cancel or dismissed dialog - NO deletion happens
      return;
    }

    // Step 3: User confirmed - now delete the file
    try {
      final fileObj = File(file.filePath);
      if (await fileObj.exists()) {
        await fileObj.delete();
      }

      // Refresh recent files list
      ref.read(labRecentFilesProvider.notifier).refresh();

      // Show system notification
      await NotificationService().showDeleteNotification(file.fileName);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('File deleted successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ─── PDF LAB ──────────────────────────────────────────────────────────────────

  Widget _buildPdfLabSection(
    BuildContext context,
    bool isDark,
    List<_LabToolData> pdfTools,
  ) {
    if (pdfTools.isEmpty) return const SizedBox.shrink();
    return _buildToolGridSection(
      context,
      title: 'PDF LAB',
      titleIcon: Icons.picture_as_pdf_rounded,
      tools: pdfTools,
      isDark: isDark,
    );
  }

  // ─── IMAGE LAB ────────────────────────────────────────────────────────────────

  Widget _buildImageLabSection(
    BuildContext context,
    bool isDark,
    List<_LabToolData> imageTools,
  ) {
    if (imageTools.isEmpty) return const SizedBox.shrink();
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
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
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
              childAspectRatio: 2.45,
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
        onTap: () => _openTool(context, tool),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
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
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color:
                    isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── DOCUMENT TOOLS ───────────────────────────────────────────────────────────

  Widget _buildDocumentToolsSection(
    BuildContext context,
    bool isDark,
    List<_LabToolData> docTools,
  ) {
    if (docTools.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOCUMENT TOOLS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
          onTap: () => _openTool(context, tool),
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

  Widget _buildUtilitiesSection(
    BuildContext context,
    bool isDark,
    List<LabRecentFile> recentFiles,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Utilities',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          _buildUtilityTile(
            context,
            isDark,
            icon: Icons.cleaning_services_rounded,
            title: 'Clean Temp Files',
            subtitle: 'Remove leftover working files from Lab operations.',
            onTap: () async {
              await LabFileManager().cleanupAllTemp();
              if (!context.mounted) return;
              _showSnack(context, 'Temporary Lab files cleared.');
            },
          ),
          _buildUtilityTile(
            context,
            isDark,
            icon: Icons.layers_clear_rounded,
            title: 'Clear Recent Outputs',
            subtitle: recentFiles.isEmpty
                ? 'No saved Lab outputs to remove from history.'
                : 'Hide ${recentFiles.length} output(s) from the recent list.',
            onTap: recentFiles.isEmpty
                ? null
                : () async {
                    await ref.read(labRecentFilesProvider.notifier).clearAll();
                    if (!context.mounted) return;
                    _showSnack(context, 'Recent Lab history cleared.');
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function()? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : _cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: _primaryBlue, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTool(BuildContext context, _LabToolData tool) {
    if (tool.route != null) {
      Navigator.pushNamed(context, tool.route!);
    }
  }

  void _showLabInfo(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How Lab helps',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _buildInfoPoint('Search tools and recent outputs from one place.'),
            _buildInfoPoint(
                'Filter the screen by PDF, image, document, or recent files.'),
            _buildInfoPoint(
                'Clean temporary files and clear output history from Lab settings.'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child:
                Icon(Icons.check_circle_rounded, size: 16, color: _primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showLabSettings(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lab Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _buildUtilityTile(
              context,
              isDark,
              icon: Icons.cleaning_services_rounded,
              title: 'Clean Temp Files',
              subtitle:
                  'Remove temporary work files created during processing.',
              onTap: () async {
                Navigator.pop(context);
                await LabFileManager().cleanupAllTemp();
                if (!mounted) return;
                _showSnack(context, 'Temporary Lab files cleared.');
              },
            ),
            _buildUtilityTile(
              context,
              isDark,
              icon: Icons.layers_clear_rounded,
              title: 'Clear Recent Outputs',
              subtitle: 'Reset the recent output carousel for this device.',
              onTap: () async {
                Navigator.pop(context);
                await ref.read(labRecentFilesProvider.notifier).clearAll();
                if (!mounted) return;
                _showSnack(context, 'Recent Lab history cleared.');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

// ─── IMAGE VIEWER SCREEN ──────────────────────────────────────────────────────

class _ImageViewerScreen extends StatelessWidget {
  final String imagePath;

  const _ImageViewerScreen({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[900],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          imagePath.split(Platform.pathSeparator).last,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PhotoView(
        imageProvider: FileImage(File(imagePath)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.grey[900],
        ),
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          ),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Could not load image',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────────────────

class _LabToolData {
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
  final String? route;

  const _LabToolData({
    required this.id,
    required this.icon,
    required this.label,
    required this.subtitle,
    this.route,
  });
}
