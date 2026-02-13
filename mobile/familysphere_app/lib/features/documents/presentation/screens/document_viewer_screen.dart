import 'dart:io';

import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  final DocumentEntity document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  String? _localPath;
  bool _renderAsPdf = false;
  bool _isLoading = true;
  String? _error;
  bool _showControls = true;
  int _currentPdfPage = 0;
  int _totalPdfPages = 0;

  bool get _isPdfByMetadata {
    final type = widget.document.fileType.toLowerCase();
    final fileUrl = widget.document.fileUrl.toLowerCase();
    final storage = widget.document.storagePath.toLowerCase();
    final title = widget.document.title.toLowerCase();

    return type.contains('pdf') ||
        fileUrl.endsWith('.pdf') ||
        storage.endsWith('.pdf') ||
        title.endsWith('.pdf');
  }

  bool get _isImage {
    final fileUrl = widget.document.fileUrl.toLowerCase();
    return widget.document.fileType.toLowerCase().startsWith('image') ||
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].any((ext) => fileUrl.endsWith('.$ext'));
  }

  @override
  void initState() {
    super.initState();
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      if (_isImage) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final result = await _downloadFile(widget.document.fileUrl, widget.document.title);
      final shouldRenderPdf = _isPdfByMetadata || _isPdfBytes(result.bytes);

      if (!mounted) return;
      if (shouldRenderPdf) {
        setState(() {
          _localPath = result.file.path;
          _renderAsPdf = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Unsupported file preview for this format';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load document: $e';
        _isLoading = false;
      });
    }
  }

  Future<_DownloadResult> _downloadFile(String url, String fileName) async {
    final encodedUrl = Uri.encodeFull(url);
    var uri = Uri.parse(encodedUrl);
    if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    }

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed (${response.statusCode})');
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception('Downloaded file is empty');
    }

    final isPdfContent = _isPdfBytes(bytes) || _isPdfByMetadata;
    final dir = await getTemporaryDirectory();
    final ext = isPdfContent ? 'pdf' : 'bin';
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${dir.path}/$safeName.$ext');
    await file.writeAsBytes(bytes, flush: true);

    return _DownloadResult(file: file, bytes: bytes);
  }

  bool _isPdfBytes(List<int> bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls ? AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        title: Text(
          widget.document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareDocument,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _downloadDocument,
            tooltip: 'Download',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Document Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Rename'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ) : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Positioned.fill(child: _buildDocumentView()),
            if (_isLoading) 
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            if (_renderAsPdf && _totalPdfPages > 0 && _showControls)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: _buildPdfControls(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentView() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isImage) {
      return PhotoView(
        imageProvider: NetworkImage(widget.document.fileUrl),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        heroAttributes: PhotoViewHeroAttributes(tag: widget.document.id),
      );
    }

    if (_renderAsPdf && _localPath != null) {
      return PDFView(
        filePath: _localPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        onPageChanged: (page, total) {
          setState(() {
            _currentPdfPage = page ?? 0;
            _totalPdfPages = total ?? 0;
          });
        },
        onRender: (pages) {
          setState(() {
            _totalPdfPages = pages ?? 0;
          });
        },
      );
    }

    return const Center(
      child: Text(
        'Unsupported file type',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildPdfControls() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'Page ${_currentPdfPage + 1} of $_totalPdfPages',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _shareDocument() async {
    try {
      if (_localPath != null) {
        await Share.shareXFiles(
          [XFile(_localPath!)],
          text: widget.document.title,
        );
      } else {
        await Share.share(
          '${widget.document.title}\n${widget.document.fileUrl}',
          subject: widget.document.title,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }

  Future<void> _downloadDocument() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started...')),
      );
      
      // Document is already downloaded locally during view preparation
      if (_localPath != null) {
        // Copy to downloads directory
        final downloadsDir = await getApplicationDocumentsDirectory();
        final fileName = widget.document.title;
        final newPath = '${downloadsDir.path}/$fileName';
        final file = File(_localPath!);
        await file.copy(newPath);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded to: $newPath')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        _showInfoSheet();
        break;
      case 'rename':
        _renameDocument();
        break;
      case 'delete':
        _deleteDocument();
        break;
    }
  }

  Future<void> _renameDocument() async {
    final controller = TextEditingController(text: widget.document.title);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Document name',
            hintText: 'Enter new name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || !mounted) return;

    // TODO: Implement rename in provider
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rename feature coming soon')),
    );
  }

  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(documentProvider.notifier).delete(widget.document);
      
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete document: $e')),
      );
    }
  }

  void _showInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.primaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Document Info',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Details and properties',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _infoRow(Icons.title_rounded, 'Title', widget.document.title),
                _infoRow(Icons.folder_outlined, 'Folder', widget.document.folder),
                _infoRow(Icons.category_outlined, 'Category', widget.document.category),
                _infoRow(
                  Icons.calendar_today_outlined,
                  'Uploaded',
                  DateFormat('MMM d, yyyy • hh:mm a').format(widget.document.uploadedAt),
                ),
                _infoRow(Icons.storage_rounded, 'Size', widget.document.fileSizeString),
                _infoRow(Icons.insert_drive_file_outlined, 'Type', widget.document.fileType),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: widget.document.fileUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    label: const Text('Copy URL'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadResult {
  final File file;
  final List<int> bytes;

  const _DownloadResult({
    required this.file,
    required this.bytes,
  });
}
