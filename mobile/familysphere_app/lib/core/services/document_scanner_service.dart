import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class DocumentScannerService {
  DocumentScannerService._();

  static Future<List<String>> scanDocument({int pageLimit = 20}) async {
    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full,
      isGalleryImport: true,
      pageLimit: pageLimit,
    );

    final documentScanner = DocumentScanner(options: options);
    try {
      final result = await documentScanner.scanDocument();
      return result.images;
    } catch (e) {
      rethrow;
    } finally {
      documentScanner.close();
    }
  }
}
