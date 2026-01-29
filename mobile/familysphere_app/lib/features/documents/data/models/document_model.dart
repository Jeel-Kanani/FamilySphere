
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

  // Firestore methods removed as we are migrating to custom backend


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
