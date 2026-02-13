
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';

class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.id,
    required super.familyId,
    required super.title,
    required super.category,
    required super.folder,
    super.memberId,
    required super.fileUrl,
    required super.fileType,
    required super.sizeBytes,
    required super.uploadedBy,
    required super.uploadedAt,
    required super.storagePath,
    super.isOfflineAvailable,
    super.localPath,
    super.deleted,
    super.deletedAt,
  });

  /// Create from Domain Entity
  factory DocumentModel.fromEntity(DocumentEntity entity) {
    return DocumentModel(
      id: entity.id,
      familyId: entity.familyId,
      title: entity.title,
      category: entity.category,
      folder: entity.folder,
      memberId: entity.memberId,
      fileUrl: entity.fileUrl,
      fileType: entity.fileType,
      sizeBytes: entity.sizeBytes,
      uploadedBy: entity.uploadedBy,
      uploadedAt: entity.uploadedAt,
      storagePath: entity.storagePath,
      isOfflineAvailable: entity.isOfflineAvailable,
      localPath: entity.localPath,
      deleted: entity.deleted,
      deletedAt: entity.deletedAt,
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

    final fileUrl = (json['fileUrl'] ?? '').toString();
    final storagePath = (json['cloudinaryId'] ?? json['storagePath'] ?? '').toString();
    final rawType = (json['fileType'] ?? '').toString();
    final lowerRawType = rawType.toLowerCase();
    final isPdfHint = lowerRawType.contains('pdf') ||
        fileUrl.toLowerCase().endsWith('.pdf') ||
        storagePath.toLowerCase().endsWith('.pdf');

    return DocumentModel(
      id: json['_id'] ?? json['id'] ?? '',
      familyId: json['familyId']?.toString() ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      folder: (json['folder'] ?? 'General').toString(),
      memberId: json['memberId']?.toString(),
      fileUrl: fileUrl,
      fileType: rawType.isNotEmpty ? rawType : (isPdfHint ? 'application/pdf' : 'application/octet-stream'),
      sizeBytes: (json['fileSize'] ?? json['size'] ?? 0) is num
          ? ((json['fileSize'] ?? json['size'] ?? 0) as num).toInt()
          : 0,
      uploadedBy: uploaderId,
      uploadedAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      storagePath: storagePath,
      isOfflineAvailable: json['isOfflineAvailable'] ?? false,
      localPath: json['localPath'],
      deleted: json['deleted'] ?? false,
      deletedAt: json['deletedAt'] != null 
          ? DateTime.parse(json['deletedAt']) 
          : null,
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'familyId': familyId,
      'title': title,
      'category': category,
      'folder': folder,
      'memberId': memberId,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': sizeBytes,
      'uploadedBy': uploadedBy,
      'cloudinaryId': storagePath,
      'createdAt': uploadedAt.toIso8601String(),
    };
  }
}
