import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';

class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.id,
    required super.familyId,
    required super.title,
    required super.category,
    required super.fileUrl,
    required super.fileType,
    required super.sizeBytes,
    required super.uploadedBy,
    required super.uploadedAt,
    required super.storagePath,
    super.isOfflineAvailable,
    super.localPath,
  });

  /// Create from Domain Entity
  factory DocumentModel.fromEntity(DocumentEntity entity) {
    return DocumentModel(
      id: entity.id,
      familyId: entity.familyId,
      title: entity.title,
      category: entity.category,
      fileUrl: entity.fileUrl,
      fileType: entity.fileType,
      sizeBytes: entity.sizeBytes,
      uploadedBy: entity.uploadedBy,
      uploadedAt: entity.uploadedAt,
      storagePath: entity.storagePath,
      isOfflineAvailable: entity.isOfflineAvailable,
      localPath: entity.localPath,
    );
  }

  /// Create from Firestore
  factory DocumentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DocumentModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      title: data['title'] ?? '',
      category: data['category'] ?? 'Uncategorized',
      fileUrl: data['fileUrl'] ?? '',
      fileType: data['fileType'] ?? 'unknown',
      sizeBytes: data['size'] ?? 0,
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      storagePath: data['storagePath'] ?? '',
    );
  }

  /// To Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'title': title,
      'category': category,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'size': sizeBytes,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'storagePath': storagePath,
    };
  }

  /// Create from JSON (for Hive)
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      familyId: json['familyId'],
      title: json['title'],
      category: json['category'],
      fileUrl: json['fileUrl'],
      fileType: json['fileType'],
      sizeBytes: json['size'],
      uploadedBy: json['uploadedBy'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
      storagePath: json['storagePath'],
      isOfflineAvailable: json['isOfflineAvailable'] ?? false,
      localPath: json['localPath'],
    );
  }

  /// To JSON (for Hive)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'title': title,
      'category': category,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'size': sizeBytes,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'storagePath': storagePath,
      'isOfflineAvailable': isOfflineAvailable,
      'localPath': localPath,
    };
  }
}
