import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final String documentUrl;

  const DocumentPreviewScreen({required this.documentUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Preview'),
      ),
      body: PDFView(
        filePath: documentUrl,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          print('Error loading PDF: $error');
        },
        onRender: (pages) {
          print('Rendered $pages pages');
        },
      ),
    );
  }
}