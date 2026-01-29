import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:familysphere_app/features/documents/data/models/document_model.dart';
import 'package:path/path.dart' as path;

class DocumentRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Upload document to Storage and Metadata to Firestore
  Future<DocumentModel> uploadDocument({
    required File file,
    required String familyId,
    required String title,
    required String category,
    required String uploadedBy,
  }) async {
    final fileName = path.basename(file.path);
    final storagePath = 'families/$familyId/documents/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(storagePath);

    // 1. Upload File
    final uploadTask = await ref.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    final size = uploadTask.totalBytes;
    
    // Determine file type
    String fileType = 'unknown';
    final ext = path.extension(fileName).toLowerCase();
    if (['.jpg', '.jpeg', '.png'].contains(ext)) {
      fileType = 'image';
    } else if (ext == '.pdf') {
      fileType = 'pdf';
    }

    // 2. Create Metadata in Firestore
    final docRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('documents')
        .doc();

    final document = DocumentModel(
      id: docRef.id,
      familyId: familyId,
      title: title,
      category: category,
      fileUrl: downloadUrl,
      fileType: fileType,
      sizeBytes: size,
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now(),
      storagePath: storagePath,
    );

    await docRef.set(document.toFirestore());

    return document;
  }

  /// Get documents for a family
  Future<List<DocumentModel>> getDocuments(String familyId, {String? category}) async {
    Query query = _firestore
        .collection('families')
        .doc(familyId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.get();
    
    return snapshot.docs
        .map((doc) => DocumentModel.fromFirestore(doc))
        .toList();
  }

  /// Delete document
  Future<void> deleteDocument({
    required String documentId,
    required String familyId,
    required String storagePath,
  }) async {
    // 1. Delete from Storage
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (e) {
      print('Storage delete error (might already be gone): $e');
    }

    // 2. Delete from Firestore
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('documents')
        .doc(documentId)
        .delete();
  }
}
