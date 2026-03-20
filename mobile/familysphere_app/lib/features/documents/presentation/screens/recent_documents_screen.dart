import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_viewer_screen.dart';
import 'package:intl/intl.dart';

class RecentDocumentsScreen extends ConsumerStatefulWidget {
  const RecentDocumentsScreen({super.key});

  @override
  ConsumerState<RecentDocumentsScreen> createState() => _RecentDocumentsScreenState();
}

class _RecentDocumentsScreenState extends ConsumerState<RecentDocumentsScreen> {
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    // Refresh documents on entry to ensure latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentProvider.notifier).loadDocuments(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final documentsState = ref.watch(documentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Sort by date descending (should already be done by provider, but ensuring here)
    final docs = [...documentsState.documents];
    docs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Recent Documents'),
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFF0F364E),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(documentProvider.notifier).loadDocuments(forceRefresh: true),
        child: documentsState.isLoading && docs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : docs.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _buildDocumentItem(doc, isDark);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No recent documents',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload documents to see them here',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(dynamic doc, bool isDark) {
    final isPdf = doc.fileType.toLowerCase().contains('pdf') || doc.fileUrl.toLowerCase().endsWith('.pdf');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: doc)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uploaded ${_dateFormat.format(doc.uploadedAt)}',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
