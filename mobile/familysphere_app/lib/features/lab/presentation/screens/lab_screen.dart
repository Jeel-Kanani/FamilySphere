import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/services/notification_service.dart';
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
        // Determine if file is image or PDF
        final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
        
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
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_vert,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        onSelected: (value) => _handleFileMenuAction(context, value, file, isDark),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Download'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Share'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Rename'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                                const SizedBox(width: 12),
                                const Text('Details'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'copy_path',
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
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
                                const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                const SizedBox(width: 12),
                                Text('Delete', style: TextStyle(color: Colors.red)),
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

  /// Handles file menu actions (download, share, rename, delete, etc.)
  void _handleFileMenuAction(BuildContext context, String action, LabRecentFile file, bool isDark) async {
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
  Future<void> _downloadFile(BuildContext context, LabRecentFile file) async {
    try {
      // Check and request storage permissions
      PermissionStatus storageStatus;
      if (Platform.isAndroid) {
        // Android 13+ requires different permissions
        final androidInfo = await Permission.storage.request();
        if (androidInfo.isDenied || androidInfo.isPermanentlyDenied) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to download files'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          await openAppSettings();
          return;
        }
        storageStatus = androidInfo;
      } else {
        storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to download files'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Show loading indicator
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Text('Downloading...'),
            ],
          ),
          duration: Duration(hours: 1), // Keep showing until we hide it
        ),
      );

      final sourceFile = File(file.filePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file not found');
      }

      final fileName = file.fileName;
      
      // Get Downloads directory with multiple fallbacks
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        // Try multiple Android Downloads paths
        final possiblePaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];
        
        for (final path in possiblePaths) {
          final dir = Directory(path);
          if (await dir.exists()) {
            downloadsDir = dir;
            break;
          }
        }
        
        // Fallback to getDownloadsDirectory
        downloadsDir ??= await getDownloadsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      
      // Final fallback to external storage directory
      downloadsDir ??= await getApplicationDocumentsDirectory();
      
      // Ensure the directory exists
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Build destination path
      var destPath = '${downloadsDir.path}${Platform.pathSeparator}$fileName';
      
      // Handle duplicate file names
      var counter = 1;
      while (await File(destPath).exists()) {
        final nameParts = fileName.split('.');
        if (nameParts.length > 1) {
          final ext = nameParts.last;
          final baseName = nameParts.sublist(0, nameParts.length - 1).join('.');
          destPath = '${downloadsDir.path}${Platform.pathSeparator}$baseName ($counter).$ext';
        } else {
          destPath = '${downloadsDir.path}${Platform.pathSeparator}$fileName ($counter)';
        }
        counter++;
      }
      
      // Copy the file
      await sourceFile.copy(destPath);
      
      // Verify the file was copied
      final copiedFile = File(destPath);
      if (!await copiedFile.exists()) {
        throw Exception('File copy verification failed');
      }
      
      final finalFileName = destPath.split(Platform.pathSeparator).last;
      
      // Show system notification
      await NotificationService().showDownloadNotification(
        fileName: finalFileName,
        filePath: destPath,
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
                children: [
                  Icon(Icons.download_done, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Downloaded Successfully!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finalFileName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved to: ${downloadsDir.path}',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check your notification & file manager',
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
                  Text('Download Failed', style: TextStyle(fontWeight: FontWeight.bold)),
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
  Future<void> _renameFile(BuildContext context, LabRecentFile file, bool isDark) async {
    final controller = TextEditingController(text: file.fileName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text('Rename File', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'New file name',
            labelStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
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
  void _showFileDetails(BuildContext context, LabRecentFile file, bool isDark) {
    final fileObj = File(file.filePath);
    final ext = file.fileName.split('.').last.toUpperCase();
    final createdDate = file.createdAt.toString().split('.')[0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text('File Details', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', file.fileName, isDark),
            const SizedBox(height: 12),
            _buildDetailRow('Type', ext, isDark),
            const SizedBox(height: 12),
            _buildDetailRow('Size', LabFileManager.formatFileSize(file.sizeBytes), isDark),
            const SizedBox(height: 12),
            _buildDetailRow('Tool', file.toolLabel, isDark),
            const SizedBox(height: 12),
            _buildDetailRow('Created', createdDate, isDark),
            const SizedBox(height: 12),
            _buildDetailRow('Location', file.filePath, isDark, isPath: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isPath = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          maxLines: isPath ? 3 : 1,
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
  Future<void> _deleteFile(BuildContext context, LabRecentFile file, bool isDark) async {
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
            Text('Delete File', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${file.fileName}"?\n\nThis action cannot be undone.',
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
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

  Widget _buildPdfLabSection(BuildContext context, bool isDark) {
    final pdfTools = [
      _LabToolData(icon: Icons.call_merge_rounded, label: 'Merge PDF', route: '/merge-pdf'),
      _LabToolData(icon: Icons.call_split_rounded, label: 'Split PDF', route: '/split-pdf'),
      _LabToolData(icon: Icons.compress_rounded, label: 'Compress'),
      _LabToolData(icon: Icons.text_snippet_rounded, label: 'To Word'),
      _LabToolData(icon: Icons.lock_rounded, label: 'Protect', route: '/protect-pdf'),
      _LabToolData(icon: Icons.rotate_right_rounded, label: 'Rotate'),
      _LabToolData(icon: Icons.lock_open_rounded, label: 'Unlock PDF', route: '/unlock-pdf'),
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
      _LabToolData(icon: Icons.aspect_ratio_rounded, label: 'Resize', route: '/image-resize'),
      _LabToolData(icon: Icons.crop_rounded, label: 'Crop Image', route: '/crop-image'),
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
