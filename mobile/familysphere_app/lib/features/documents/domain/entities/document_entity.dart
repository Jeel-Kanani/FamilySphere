/// Document Entity
/// 
/// Represents a file stored in the system (PDF, Image, etc.)
class DocumentEntity {
  final String id;
  final String familyId;
  final String title;
  final String category;
  final String folder;
  final String? memberId;
  final String fileUrl;
  final String fileType; // 'pdf', 'image', etc.
  final int sizeBytes;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String storagePath;
  final bool isOfflineAvailable;
  final String? localPath;

  const DocumentEntity({
    required this.id,
    required this.familyId,
    required this.title,
    required this.category,
    this.folder = 'General',
    this.memberId,
    required this.fileUrl,
    required this.fileType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.storagePath,
    this.isOfflineAvailable = false,
    this.localPath,
  });

  /// Readable file size
  String get fileSizeString {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Copy with method
  DocumentEntity copyWith({
    String? id,
    String? familyId,
    String? title,
    String? category,
    String? folder,
    String? memberId,
    String? fileUrl,
    String? fileType,
    int? sizeBytes,
    String? uploadedBy,
    DateTime? uploadedAt,
    String? storagePath,
    bool? isOfflineAvailable,
    String? localPath,
  }) {
    return DocumentEntity(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      title: title ?? this.title,
      category: category ?? this.category,
      folder: folder ?? this.folder,
      memberId: memberId ?? this.memberId,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      storagePath: storagePath ?? this.storagePath,
      isOfflineAvailable: isOfflineAvailable ?? this.isOfflineAvailable,
      localPath: localPath ?? this.localPath,
    );
  }
}
