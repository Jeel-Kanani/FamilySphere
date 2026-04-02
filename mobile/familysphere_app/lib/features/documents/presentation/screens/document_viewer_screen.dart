import 'dart:io';

import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/confirm_type_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/document_intelligence_card.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/ocr_status_banner.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  final DocumentEntity document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  String? _localPath;
  bool _renderAsPdf = false;
  bool _isLoading = true;
  String? _error;
  bool _showControls = true;
  int _currentPdfPage = 0;
  int _totalPdfPages = 0;

  bool get _isImage {
    final fileUrl = widget.document.fileUrl.toLowerCase();
    return widget.document.fileType.toLowerCase().startsWith('image') ||
        ['jpg', 'jpeg', 'png', 'gif', 'webp']
            .any((ext) => fileUrl.endsWith('.$ext'));
  }

  @override
  void initState() {
    super.initState();
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      final currentDoc = ref.read(documentProvider).documents.firstWhere(
            (d) => d.id == widget.document.id,
            orElse: () => widget.document,
          );

      if (_isImage &&
          !(currentDoc.localPath != null &&
              currentDoc.localPath!.isNotEmpty &&
              await File(currentDoc.localPath!).exists())) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final localPath = await ref
          .read(documentProvider.notifier)
          .prepareForViewing(currentDoc);
      final shouldRenderPdf = _isPdfDocument(currentDoc);

      if (!mounted) return;
      if (localPath != null) {
        setState(() {
          _localPath = localPath;
          _renderAsPdf = shouldRenderPdf;
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

  bool _isPdfDocument(DocumentEntity document) {
    final type = document.fileType.toLowerCase();
    final fileUrl = document.fileUrl.toLowerCase();
    final storage = document.storagePath.toLowerCase();
    final title = document.title.toLowerCase();

    return type.contains('pdf') ||
        fileUrl.endsWith('.pdf') ||
        storage.endsWith('.pdf') ||
        title.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch the live document list to get real-time status updates (like OCR completion)
    final documents = ref.watch(documentProvider).documents;
    final syncError = ref.watch(
      documentProvider
          .select((s) => s.syncErrorsByDocumentId[widget.document.id]),
    );
    final syncJobType = ref.watch(
      documentProvider
          .select((s) => s.syncJobTypesByDocumentId[widget.document.id]),
    );
    final currentDoc = documents.firstWhere(
      (d) => d.id == widget.document.id,
      orElse: () => widget.document,
    );

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              title: Text(
                currentDoc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => _shareDocument(currentDoc),
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => _downloadDocument(currentDoc),
                  tooltip: 'Download',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) => _handleMenuAction(action, currentDoc),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'offline_toggle',
                      child: Row(
                        children: [
                          Icon(Icons.offline_pin_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Toggle Offline Copy'),
                        ],
                      ),
                    ),
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
                          Icon(Icons.delete_outline_rounded,
                              size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Positioned.fill(child: _buildDocumentView(currentDoc)),
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
            if (currentDoc.syncStatus == 'pending_upload' ||
                currentDoc.syncStatus == 'pending_move' ||
                currentDoc.syncStatus == 'sync_failed')
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child:
                    _buildSyncStatusBanner(currentDoc, syncError, syncJobType),
              ),
            // Confirmation overlay when AI is uncertain or has analyzed the document
            if (currentDoc.ocrStatus == 'needs_confirmation' ||
                currentDoc.ocrStatus == 'analyzed')
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: ConfirmTypeBanner(
                  docId: currentDoc.id,
                  aiDetectedType: currentDoc.docType ?? '',
                  onConfirmed: () {
                    ref.read(documentProvider.notifier).loadDocuments();
                  },
                  onReviewInsights: () => _showInfoSheet(currentDoc),
                ),
              ),

            // Phase 6 – Real-time OCR status banner (only for pending/processing)
            if (currentDoc.ocrStatus == 'pending' ||
                currentDoc.ocrStatus == 'processing')
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: OcrStatusBanner(
                  docId: currentDoc.id,
                  onDone: () {
                    // Refresh document list to get latest metadata
                    ref.read(documentProvider.notifier).loadDocuments();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentView(DocumentEntity currentDoc) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.white70),
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
      final imageProvider = _localPath != null && File(_localPath!).existsSync()
          ? FileImage(File(_localPath!))
          : NetworkImage(currentDoc.fileUrl) as ImageProvider;
      return PhotoView(
        imageProvider: imageProvider,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        heroAttributes: PhotoViewHeroAttributes(tag: currentDoc.id),
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
          color: Colors.black.withValues(alpha: 0.7),
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

  String _syncJobTypeLabel(String? syncJobType) {
    switch (syncJobType) {
      case 'upload':
        return 'Upload sync';
      case 'move':
        return 'Move sync';
      case 'delete':
        return 'Delete sync';
      default:
        return 'Sync';
    }
  }

  Widget _buildSyncStatusBanner(
      DocumentEntity currentDoc, String? syncError, String? syncJobType) {
    final syncStatus = currentDoc.syncStatus;
    final isFailed = syncStatus == 'sync_failed';
    final isMove = syncStatus == 'pending_move';
    final hasConflict =
        ref.read(documentProvider.notifier).hasConflictForDocument(currentDoc.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isFailed ? const Color(0xFF7F1D1D) : const Color(0xFF082F49))
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isFailed ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9))
              .withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFailed
                    ? Icons.error_outline_rounded
                    : isMove
                        ? Icons.drive_file_move_rounded
                        : Icons.cloud_upload_rounded,
                color: isFailed
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFF38BDF8),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFailed
                      ? 'Sync failed after several retries.'
                      : isMove
                          ? 'This folder change is saved locally and waiting to sync.'
                          : 'This document is saved locally and waiting to sync.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (isFailed && syncError != null && syncError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _syncJobTypeLabel(syncJobType),
              style: const TextStyle(
                color: Color(0xFFFECACA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              syncError,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFECACA),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasConflict)
                    OutlinedButton.icon(
                      onPressed: () => _resolveConflict(currentDoc),
                      icon: const Icon(Icons.build_circle_outlined, size: 16),
                      label: const Text('Resolve Conflict'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFECACA),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _retryFailedSync(currentDoc),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry This Document'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _clearFailedSync(currentDoc),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text('Clear Failed Sync'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFECACA),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _shareDocument(DocumentEntity currentDoc) async {
    try {
      if (_localPath != null) {
        await Share.shareXFiles(
          [XFile(_localPath!)],
          text: currentDoc.title,
        );
      } else {
        await Share.share(
          '${currentDoc.title}\n${currentDoc.fileUrl}',
          subject: currentDoc.title,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }

  Future<void> _resolveConflict(DocumentEntity currentDoc) async {
    try {
      await ref
          .read(documentProvider.notifier)
          .resolveFailedSyncConflict(currentDoc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conflict resolution applied')),
      );
      await ref.read(documentProvider.notifier).loadDocuments(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve conflict: $e')),
      );
    }
  }

  Future<void> _downloadDocument(DocumentEntity currentDoc) async {
    try {
      final encryptedPath =
          await ref.read(documentProvider.notifier).download(currentDoc);
      if (encryptedPath == null || !mounted) return;
      final readablePath =
          await ref.read(documentProvider.notifier).prepareForViewing(
                currentDoc.copyWith(
                  localPath: encryptedPath,
                  isOfflineAvailable: true,
                ),
              );
      if (readablePath == null || !mounted) return;
      setState(() {
        _localPath = readablePath;
        _renderAsPdf = _isPdfDocument(currentDoc);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for offline access')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  void _handleMenuAction(String action, DocumentEntity currentDoc) {
    switch (action) {
      case 'offline_toggle':
        _toggleOfflineCopy(currentDoc);
        break;
      case 'info':
        _showInfoSheet(currentDoc);
        break;
      case 'rename':
        _renameDocument(currentDoc);
        break;
      case 'delete':
        _deleteDocument(currentDoc);
        break;
    }
  }

  Future<void> _toggleOfflineCopy(DocumentEntity currentDoc) async {
    try {
      if (currentDoc.isOfflineAvailable) {
        await ref.read(documentProvider.notifier).removeOfflineCopy(currentDoc);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline copy removed')),
        );
        return;
      }

      final encryptedPath =
          await ref.read(documentProvider.notifier).download(currentDoc);
      if (encryptedPath == null || !mounted) return;
      final readablePath =
          await ref.read(documentProvider.notifier).prepareForViewing(
                currentDoc.copyWith(
                  localPath: encryptedPath,
                  isOfflineAvailable: true,
                ),
              );
      if (readablePath == null || !mounted) return;
      setState(() {
        _localPath = readablePath;
        _renderAsPdf = _isPdfDocument(currentDoc);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for offline access')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Offline copy update failed: $e')),
      );
    }
  }

  Future<void> _renameDocument(DocumentEntity currentDoc) async {
    final controller = TextEditingController(text: currentDoc.title);

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

  Future<void> _deleteDocument(DocumentEntity currentDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
            'Are you sure you want to delete this document? This action cannot be undone.'),
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
      await ref.read(documentProvider.notifier).delete(currentDoc);

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

  Future<void> _retryFailedSync(DocumentEntity currentDoc) async {
    try {
      await ref
          .read(documentProvider.notifier)
          .retryFailedSyncForDocument(currentDoc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retrying sync for this document')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to retry document sync: $e')),
      );
    }
  }

  Future<void> _clearFailedSync(DocumentEntity currentDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Failed Sync'),
        content: Text(
          currentDoc.id.startsWith('local-doc-')
              ? 'This will remove the failed local upload from the sync queue and delete its pending offline copy.'
              : 'This will remove the failed sync job for this document from the queue on this device.',
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
      await ref
          .read(documentProvider.notifier)
          .clearFailedSyncForDocument(currentDoc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed sync cleared for this document')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear document sync: $e')),
      );
    }
  }

  void _showInfoSheet(DocumentEntity currentDoc) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final syncError =
            ref.read(documentProvider).syncErrorsByDocumentId[currentDoc.id];
        final syncJobType =
            ref.read(documentProvider).syncJobTypesByDocumentId[currentDoc.id];
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
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                            AppTheme.primaryColor.withValues(alpha: 0.1),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'Details and properties',
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
                const SizedBox(height: 24),
                _infoRow(Icons.title_rounded, 'Title', currentDoc.title),
                _infoRow(Icons.folder_outlined, 'Folder', currentDoc.folder),
                _infoRow(
                    Icons.category_outlined, 'Category', currentDoc.category),
                _infoRow(
                  Icons.calendar_today_outlined,
                  'Uploaded',
                  DateFormat('MMM d, yyyy • hh:mm a')
                      .format(currentDoc.uploadedAt),
                ),
                _infoRow(
                    Icons.storage_rounded, 'Size', currentDoc.fileSizeString),
                _infoRow(Icons.insert_drive_file_outlined, 'Type',
                    currentDoc.fileType),
                _infoRow(
                  Icons.offline_pin_rounded,
                  'Offline',
                  currentDoc.isOfflineAvailable
                      ? 'Available on device'
                      : 'Not saved offline',
                ),
                _infoRow(
                  Icons.cloud_sync_rounded,
                  'Sync',
                  currentDoc.syncStatus == 'pending_upload'
                      ? 'Pending upload'
                      : currentDoc.syncStatus == 'pending_move'
                          ? 'Pending move'
                          : currentDoc.syncStatus == 'sync_failed'
                              ? 'Failed, retry needed'
                              : 'Synced',
                ),
                if (currentDoc.syncStatus == 'sync_failed' &&
                    syncJobType != null &&
                    syncJobType.isNotEmpty)
                  _infoRow(
                    Icons.sync_problem_rounded,
                    'Failed Job Type',
                    _syncJobTypeLabel(syncJobType),
                  ),
                if (currentDoc.syncStatus == 'sync_failed' &&
                    syncError != null &&
                    syncError.isNotEmpty)
                  _infoRow(
                    Icons.error_outline_rounded,
                    'Last Sync Error',
                    syncError,
                  ),
                const SizedBox(height: 24),

                // Smart Intelligence Card
                DocumentIntelligenceCard(docId: currentDoc.id),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Clipboard.setData(
                          ClipboardData(text: currentDoc.fileUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('URL copied to clipboard')),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
