import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String documentUrl;

  const DocumentPreviewScreen({required this.documentUrl});

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _showPageIndicator = true;

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
        title: const Text(
          'PDF Viewer',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1} / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer with smooth scrolling and high quality rendering
          PDFView(
            filePath: widget.documentUrl,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: false, // ✅ Disabled page fling for smooth scrolling
            pageSnap: false,  // ✅ Disabled page snap for continuous scroll
            fitPolicy: FitPolicy.WIDTH,
            fitEachPage: true, // ✅ Fit each page for better quality
            nightMode: false,  // ✅ Normal rendering mode
            preventLinkNavigation: false,
            onError: (error) {
              debugPrint('Error loading PDF: $error');
            },
            onRender: (pages) {
              setState(() {
                _totalPages = pages ?? 0;
              });
              debugPrint('Rendered $_totalPages pages');
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                _currentPage = page ?? 0;
                _totalPages = total ?? 0;
              });
            },
            onPageError: (page, error) {
              debugPrint('Error on page $page: $error');
            },
          ),

          // Floating page indicator (appears briefly when scrolling)
          if (_showPageIndicator && _totalPages > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}