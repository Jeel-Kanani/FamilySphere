import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class DocumentViewerScreen extends StatefulWidget {
  final DocumentEntity document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  int _currentTab = 0; // 0 for View, 1 for Pages grid
  int _currentPageIndex = 0;
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  bool _showInfo = false;

  // Mocking multiple pages for UI demo
  final List<String> _pageUrls = [];

  @override
  void initState() {
    super.initState();
    _pageUrls.add(widget.document.fileUrl);
    // Add mock pages if it's a multi-page doc
    _pageUrls.addAll([
      widget.document.fileUrl,
      widget.document.fileUrl,
    ]);
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      if (widget.document.fileType == 'pdf') {
        final file = await _downloadFile(widget.document.fileUrl, widget.document.title);
        if (mounted) {
          setState(() {
            _localPath = file.path;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<File> _downloadFile(String url, String fileName) async {
    final response = await http.get(Uri.parse(url));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.document.title, style: const TextStyle(fontSize: 16)),
            if (_currentTab == 0)
              Text(
                'Page ${_currentPageIndex + 1}/${_pageUrls.length}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showInfo ? Icons.info : Icons.info_outline),
            onPressed: () => setState(() => _showInfo = !_showInfo),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          _currentTab == 0 ? _buildPageView() : _buildPagesGrid(),
          if (_showInfo) _buildInfoPanel(),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        backgroundColor: Colors.black,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.white60,
        onTap: (index) => setState(() => _currentTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.remove_red_eye), label: 'View'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Pages'),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.white)));
    }

    if (widget.document.fileType == 'image') {
      return PageView.builder(
        itemCount: _pageUrls.length,
        onPageChanged: (i) => setState(() => _currentPageIndex = i),
        itemBuilder: (context, index) {
          return PhotoView(
            imageProvider: NetworkImage(_pageUrls[index]),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          );
        },
      );
    } else if (widget.document.fileType == 'pdf' && _localPath != null) {
      return PDFView(
        filePath: _localPath,
        enableSwipe: true,
        swipeHorizontal: true,
      );
    }
    return const Center(child: Text('Unsupported file type', style: TextStyle(color: Colors.white)));
  }

  Widget _buildPagesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: _pageUrls.length,
      itemBuilder: (context, index) {
        final isSelected = _currentPageIndex == index;
        return GestureDetector(
          onTap: () => setState(() {
            _currentTab = 0;
            _currentPageIndex = index;
          }),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : Colors.white24,
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(_pageUrls[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Page ${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Document Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showInfo = false),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(Icons.category_outlined, 'Category', widget.document.category),
            _buildInfoRow(Icons.calendar_today_outlined, 'Uploaded', DateFormat('MMM d, y').format(widget.document.uploadedAt)),
            _buildInfoRow(Icons.description_outlined, 'File Size', widget.document.fileSizeString),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Download Locally'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
