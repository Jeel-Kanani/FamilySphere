import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DocumentViewerScreen extends StatefulWidget {
  final DocumentEntity document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      if (widget.document.fileType == 'pdf') {
        // For PDFs, we need a local file to display with flutter_pdfview
        final file = await _downloadFile(widget.document.fileUrl, widget.document.title);
        if (mounted) {
          setState(() {
            _localPath = file.path;
            _isLoading = false;
          });
        }
      } else {
        // Images can be loaded directly from network
        setState(() {
          _isLoading = false;
        });
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
    final bytes = response.bodyBytes;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf'); // Simple temp storage
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Implement permanent download to device storage
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error loading document: $_error'));
    }

    if (widget.document.fileType == 'image') {
      return PhotoView(
        imageProvider: NetworkImage(widget.document.fileUrl),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      );
    } else if (widget.document.fileType == 'pdf' && _localPath != null) {
      return PDFView(
        filePath: _localPath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: false,
        onError: (error) {
          print(error.toString());
        },
        onPageError: (page, error) {
          print('$page: ${error.toString()}');
        },
      );
    } else {
      return const Center(child: Text('Unsupported file type'));
    }
  }
}
