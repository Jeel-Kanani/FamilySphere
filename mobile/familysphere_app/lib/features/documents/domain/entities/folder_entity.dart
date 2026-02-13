class FolderEntity {
  final String name;
  final bool isBuiltIn;
  final bool isCustom;
  final String? folderId;
  final bool isSystem;

  FolderEntity({
    required this.name,
    required this.isBuiltIn,
    required this.isCustom,
    this.folderId,
    required this.isSystem,
  });

  bool get canDelete => true; // Allow all folders to be deletable
}
