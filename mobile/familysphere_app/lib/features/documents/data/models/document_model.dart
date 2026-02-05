
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


  /// Create from JSON (from API)
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    // Handle both populated and non-populated uploadedBy
    String uploaderId = '';
    if (json['uploadedBy'] is Map) {
      uploaderId = json['uploadedBy']['_id'] ?? '';
    } else {
      uploaderId = json['uploadedBy']?.toString() ?? '';
    }

    return DocumentModel(
      id: json['_id'] ?? json['id'] ?? '',
      familyId: json['familyId']?.toString() ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      fileType: json['fileType'] ?? '',
      sizeBytes: (json['fileSize'] ?? json['size'] ?? 0) as int,
      uploadedBy: uploaderId,
      uploadedAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      storagePath: json['cloudinaryId'] ?? json['storagePath'] ?? '',
      isOfflineAvailable: json['isOfflineAvailable'] ?? false,
      localPath: json['localPath'],
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'familyId': familyId,
      'title': title,
      'category': category,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': sizeBytes,
      'uploadedBy': uploadedBy,
      'cloudinaryId': storagePath,
      'createdAt': uploadedAt.toIso8601String(),
    };
  }
}
