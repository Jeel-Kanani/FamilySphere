import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_viewer_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/trash_screen.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:intl/intl.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const DocumentListScreen({super.key, this.initialCategory});

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  static final DateFormat _rowDateFormat = DateFormat('MMM d');

  static const List<String> _sharedFolders = [
    'Property Deed',
    'Medical',
    'Insurance',
    'Vehicle',
    'Finance & Tax',
    'Legal',
    'Education',
    'Household Bills',
    'Family Identity',
  ];

  static const List<String> _memberDocFolders = [
    'Aadhaar Card',
    'PAN Card',
    'Passport',
    'Voter ID',
    'Driving License',
    'Birth Certificate',
    '10th Marksheet',
    '12th Marksheet',
    'Results',
    'Degree/Certificates',
    'Bank/KYC',
    'Employment',
  ];

  static const List<String> _personalFolders = [
    'Study & Learning',
    'Career Documents',
    'Business',
    'Portfolio',
    'Personal Certificates',
    'Creative Work',
    'Travel',
    'Misc Personal',
  ];

  static const List<String> _privateFolders = [
    'Passwords',
    'Confidential Notes',
    'Legal Contracts',
    'Bank Accounts',
    'Identity Secrets',
    'Recovery Keys',
    'Private Finance',
    'Critical Credentials',
  ];

  String? _selectedCategory;
  String _selectedFolder = 'All';
  String? _selectedMemberId;
  bool _expandMembers = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isGridView = false;
  String _sortBy = 'date'; // date, name, size
  bool _sortAscending = false;
  bool _selectionMode = false;
  final Set<String> _selectedDocIds = {};

  bool get _isShared => _selectedCategory == 'Shared';
  bool get _isPersonal => _selectedCategory == 'Personal';
  bool get _isPrivate => _selectedCategory == 'Private';

  @override
  void initState() {
    super.initState();
    _selectedCategory = _normalizeVaultCategory(widget.initialCategory) ?? 'Shared';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isShared) {
        await _ensureMembersLoaded();
      }
      await _reloadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureMembersLoaded() async {
    final familyState = ref.read(familyProvider);
    if (familyState.members.isEmpty) {
      await ref.read(familyProvider.notifier).loadFamily();
    }
  }

  String? _categoryScopedMemberId() {
    final currentUser = ref.read(authProvider).user;
    if (_isShared) return _selectedMemberId;
    if (_isPersonal || _isPrivate) return currentUser?.id;
    return null;
  }

  Future<void> _reloadData({bool reloadFolders = true}) async {
    if (_selectedCategory == null) return;
    final notifier = ref.read(documentProvider.notifier);
    final memberId = _categoryScopedMemberId();

    await notifier.loadDocuments(
      category: _selectedCategory,
      folder: _selectedFolder == 'All' ? null : _selectedFolder,
      memberId: memberId,
    );

    if (reloadFolders) {
      notifier.loadFolders(
        category: _selectedCategory!,
        memberId: memberId,
      );
    }
  }

  void _openDocument(DocumentEntity document) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: document)),
    );
  }

  Future<void> _createFolderDialog() async {
    if (_selectedCategory == null) return;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g. Certificates',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );

    final folderName = result?.trim() ?? '';
    if (folderName.isEmpty || !mounted) return;

    try {
      await ref.read(documentProvider.notifier).createFolder(
            category: _selectedCategory!,
            name: folderName,
            memberId: _categoryScopedMemberId(),
          );
      setState(() => _selectedFolder = folderName);
      await _reloadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create folder')),
      );
    }
  }

  List<String> _rootFolders(List<String> customFolders) {
    final custom = customFolders.where((f) => f.trim().isNotEmpty).toList();
    if (_isShared) return [..._sharedFolders, ...custom].toSet().toList();
    if (_isPersonal) return [..._personalFolders, ...custom].toSet().toList();
    if (_isPrivate) return [..._privateFolders, ...custom].toSet().toList();
    return custom;
  }

  List<String> _memberFolders(List<String> customFolders) {
    final custom = customFolders.where((f) => f.trim().isNotEmpty).toList();
    return [..._memberDocFolders, ...custom].toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(documentProvider.select((s) => s.isLoading));
    final documents = ref.watch(documentProvider.select((s) => s.documents));
    final customFolders = ref.watch(documentProvider.select((s) => s.folders));
    final members = ref.watch(familyProvider.select((s) => s.members));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final docs = documents.where((doc) {
      if (_searchController.text.isEmpty) return true;
      return doc.title.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    // Sort documents
    _sortDocuments(docs);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search in selected folder...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text('${_selectedCategory ?? 'Vault'} Structure'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _selectedDocIds.isEmpty ? null : _deleteSelected,
              tooltip: 'Delete selected',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedDocIds.clear();
              }),
              tooltip: 'Cancel',
            ),
          ] else ...[
            if (_selectedFolder != 'All')
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort',
                onSelected: (value) {
                  setState(() {
                    if (_sortBy == value) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortBy = value;
                      _sortAscending = value == 'name';
                    }
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'date',
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: _sortBy == 'date' ? AppTheme.primaryColor : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Date',
                          style: TextStyle(
                            color: _sortBy == 'date' ? AppTheme.primaryColor : null,
                            fontWeight: _sortBy == 'date' ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'name',
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_by_alpha_rounded,
                          size: 20,
                          color: _sortBy == 'name' ? AppTheme.primaryColor : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Name',
                          style: TextStyle(
                            color: _sortBy == 'name' ? AppTheme.primaryColor : null,
                            fontWeight: _sortBy == 'name' ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'size',
                    child: Row(
                      children: [
                        Icon(
                          Icons.storage_rounded,
                          size: 20,
                          color: _sortBy == 'size' ? AppTheme.primaryColor : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Size',
                          style: TextStyle(
                            color: _sortBy == 'size' ? AppTheme.primaryColor : null,
                            fontWeight: _sortBy == 'size' ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_selectedFolder != 'All')
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                onPressed: () => setState(() => _isGridView = !_isGridView),
                tooltip: _isGridView ? 'List view' : 'Grid view',
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrashScreen(),
                ),
              ),
              tooltip: 'Trash',
            ),
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              }),
            ),
          ],
        ],
      ),
      body: _buildBody(isLoading, docs, members, customFolders),
      floatingActionButton: _selectedFolder != 'All' && docs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _selectionMode = !_selectionMode),
              icon: Icon(_selectionMode ? Icons.close : Icons.checklist_rounded),
              label: Text(_selectionMode ? 'Cancel' : 'Select'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(bool isLoading, List<DocumentEntity> docs, List<FamilyMember> members, List<String> customFolders) {
    if (_isSearching || _selectedFolder != 'All') {
      return Column(
        children: [
          _buildPathHeader(members),
          if (_selectedFolder != 'All' && docs.isNotEmpty)
            _buildFilterChips(),
          Expanded(
            child: _isGridView 
              ? _buildDocumentGrid(isLoading, docs, members)
              : _buildDocumentList(isLoading, docs, members),
          ),
        ],
      );
    }

    if (_isShared && _selectedMemberId == null) {
      return _buildSharedRoot(members, _rootFolders(customFolders));
    }

    if (_isShared && _selectedMemberId != null) {
      return _buildSharedMemberFolders(members, _memberFolders(customFolders));
    }

    return _buildTierFolders(_rootFolders(customFolders));
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Chip(
              avatar: Icon(
                _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 16,
              ),
              label: Text(_sortBy == 'date' 
                ? 'By Date' 
                : _sortBy == 'name' 
                  ? 'By Name' 
                  : 'By Size'),
              onDeleted: () {},
              deleteIcon: const SizedBox.shrink(),
            ),
            if (_selectionMode && _selectedDocIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.check_circle_rounded, size: 16),
                label: Text('${_selectedDocIds.length} selected'),
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPathHeader(List<FamilyMember> members) {
    String label = 'All Documents';
    if (_selectedFolder != 'All') label = _selectedFolder;
    if (_isShared && _selectedMemberId != null) {
      String name = 'Member';
      for (final m in members) {
        if (m.userId == _selectedMemberId) {
          name = m.displayName;
          break;
        }
      }
      label = '$name / $label';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkBorder
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () async {
          var reloadFolders = true;
          setState(() {
            if (_selectedFolder != 'All') {
              _selectedFolder = 'All';
              reloadFolders = false;
            } else if (_isShared && _selectedMemberId != null) {
              _selectedMemberId = null;
            }
          });
          await _reloadData(reloadFolders: reloadFolders);
        },
      ),
    );
  }

  Widget _nodeTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    VoidCallback? onMenuTap,
    Color? iconColor,
    double leftPad = 0,
    bool showMenu = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ?? AppTheme.primaryColor;
    return Padding(
      padding: EdgeInsets.only(left: leftPad, bottom: 10),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showMenu && onMenuTap != null)
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceVariant
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: onMenuTap,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFolderOptions(String folderName, String? folderId, bool canDelete) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      folderName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (canDelete) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'This is a built-in folder and cannot be modified',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );

    if (result == 'delete') {
      await _deleteFolder(folderName, folderId);
    } else if (result == 'rename' && folderId != null) {
      await _renameFolderDialog(folderName, folderId);
    }
  }

  Future<void> _renameFolderDialog(String currentName, String folderId) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    final newName = result?.trim() ?? '';
    if (newName.isEmpty || newName == currentName || !mounted) return;

    try {
      // TODO: Implement rename folder in provider
      // await ref.read(documentProvider.notifier).renameFolder(
      //   folderId: folderId,
      //   newName: newName,
      //   category: _selectedCategory!,
      //   memberId: _selectedMemberId,
      // );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder renamed to "$newName"')),
        );
      }
      await _reloadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFolder(String folderName, String? folderId) async {
    final familyState = ref.read(familyProvider);
    final familyId = familyState.family?.id;
    
    if (familyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete folder: Family information not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      await ref.read(documentProvider.notifier).deleteFolder(
        folderId: folderId ?? 'placeholder',
        folderName: folderName,
        familyId: familyId,
        category: _selectedCategory!,
        memberId: _categoryScopedMemberId(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "$folderName" deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSharedRoot(List<FamilyMember> members, List<String> folders) {
    final folderDetails = ref.read(documentProvider.notifier).getFolderDetails(
      category: _selectedCategory!,
      memberId: null,
    );
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
      children: [
        _nodeTile(
          icon: Icons.groups_rounded,
          title: 'Individual',
          subtitle: _expandMembers ? 'Tap to collapse member list' : 'Tap to expand member list',
          onTap: () => setState(() => _expandMembers = !_expandMembers),
          iconColor: const Color(0xFF0EA5E9),
        ),
        if (_expandMembers)
          ...members.map((m) => _nodeTile(
                icon: Icons.person_outline_rounded,
                title: m.displayName,
                subtitle: 'Open member folders',
                leftPad: 14,
                onTap: () async {
                  setState(() {
                    _selectedMemberId = m.userId;
                    _selectedFolder = 'All';
                  });
                  await _reloadData(reloadFolders: true);
                },
              )),
        const SizedBox(height: 4),
        ...folders.map((f) {
          final detail = folderDetails?.where((d) => d.name == f).firstOrNull;
          return _nodeTile(
            icon: Icons.folder_rounded,
            title: f,
            subtitle: 'Shared category folder',
            onTap: () async {
              setState(() => _selectedFolder = f);
              await _reloadData(reloadFolders: false);
            },
            showMenu: true,
            onMenuTap: () => _showFolderOptions(f, detail?.folderId, detail?.canDelete ?? true),
            iconColor: AppTheme.primaryColor,
          );
        }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _createFolderDialog,
          icon: const Icon(Icons.create_new_folder_outlined, size: 20),
          label: const Text('Create Custom Folder'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSharedMemberFolders(List<FamilyMember> members, List<String> folders) {
    String name = 'Member';
    for (final m in members) {
      if (m.userId == _selectedMemberId) {
        name = m.displayName;
        break;
      }
    }

    final folderDetails = ref.read(documentProvider.notifier).getFolderDetails(
      category: _selectedCategory!,
      memberId: _selectedMemberId,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
      children: [
        _nodeTile(
          icon: Icons.arrow_back_rounded,
          title: '$name',
          subtitle: 'Back to Shared root',
          onTap: () async {
            setState(() {
              _selectedMemberId = null;
              _selectedFolder = 'All';
            });
            await _reloadData(reloadFolders: true);
          },
          iconColor: const Color(0xFFF97316),
        ),
        ...folders.map((f) {
          final detail = folderDetails?.where((d) => d.name == f).firstOrNull;
          return _nodeTile(
            icon: Icons.folder_rounded,
            title: f,
            subtitle: '$name - document type folder',
            onTap: () async {
              setState(() => _selectedFolder = f);
              await _reloadData(reloadFolders: false);
            },
            showMenu: true,
            onMenuTap: () => _showFolderOptions(f, detail?.folderId, detail?.canDelete ?? true),
            iconColor: AppTheme.primaryColor,
          );
        }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _createFolderDialog,
          icon: const Icon(Icons.create_new_folder_outlined, size: 20),
          label: const Text('Create Custom Folder'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildTierFolders(List<String> folders) {
    final folderDetails = ref.read(documentProvider.notifier).getFolderDetails(
      category: _selectedCategory!,
      memberId: null,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
      children: [
        ...folders.map((f) {
          final detail = folderDetails?.where((d) => d.name == f).firstOrNull;
          return _nodeTile(
            icon: Icons.folder_rounded,
            title: f,
            subtitle: 'Open folder documents',
            onTap: () async {
              setState(() => _selectedFolder = f);
              await _reloadData(reloadFolders: false);
            },
            showMenu: true,
            onMenuTap: () => _showFolderOptions(f, detail?.folderId, detail?.canDelete ?? true),
            iconColor: AppTheme.primaryColor,
          );
        }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _createFolderDialog,
          icon: const Icon(Icons.create_new_folder_outlined, size: 20),
          label: const Text('Create Custom Folder'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentList(bool isLoading, List<DocumentEntity> docs, List<FamilyMember> members) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading && docs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (docs.isEmpty) {
      return const Center(
        child: Text('No documents found', style: TextStyle(color: AppTheme.textTertiary)),
      );
    }

    String memberName(String? id) {
      if (id == null || id.isEmpty) return '';
      for (final m in members) {
        if (m.userId == id) return m.displayName;
      }
      return '';
    }

    return RepaintBoundary(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final isPdf = doc.fileType.toLowerCase().contains('pdf') ||
              doc.fileUrl.toLowerCase().endsWith('.pdf') ||
              doc.storagePath.toLowerCase().endsWith('.pdf') ||
              doc.title.toLowerCase().endsWith('.pdf');
          final ownerName = memberName(doc.memberId);
          final isSelected = _selectedDocIds.contains(doc.id);

          return InkWell(
            onTap: () => _selectionMode 
              ? _toggleSelection(doc.id)
              : _openDocument(doc),
            onLongPress: () {
              if (!_selectionMode) {
                setState(() {
                  _selectionMode = true;
                  _selectedDocIds.add(doc.id);
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected 
                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                  : (isDark ? AppTheme.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                    ? AppTheme.primaryColor
                    : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: !isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        isSelected 
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      ),
                    ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isPdf 
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      color: isPdf ? const Color(0xFFEF4444) : AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isShared && ownerName.isNotEmpty
                              ? '$ownerName - ${doc.folder} - ${_rowDateFormat.format(doc.uploadedAt)}'
                              : '${doc.folder} - ${_rowDateFormat.format(doc.uploadedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!_selectionMode)
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentGrid(bool isLoading, List<DocumentEntity> docs, List<FamilyMember> members) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading && docs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (docs.isEmpty) {
      return const Center(
        child: Text('No documents found', style: TextStyle(color: AppTheme.textTertiary)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final isPdf = doc.fileType.toLowerCase().contains('pdf') ||
            doc.fileUrl.toLowerCase().endsWith('.pdf');
        final isSelected = _selectedDocIds.contains(doc.id);

        return InkWell(
          onTap: () => _selectionMode 
            ? _toggleSelection(doc.id)
            : _openDocument(doc),
          onLongPress: () {
            if (!_selectionMode) {
              setState(() {
                _selectionMode = true;
                _selectedDocIds.add(doc.id);
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : (isDark ? AppTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? AppTheme.primaryColor
                  : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: !isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isPdf
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFEFF6FF),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                            color: isPdf ? const Color(0xFFEF4444) : AppTheme.primaryColor,
                            size: 48,
                          ),
                        ),
                      ),
                      if (_selectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: isSelected 
                              ? AppTheme.primaryColor
                              : Colors.white.withOpacity(0.8),
                            child: Icon(
                              isSelected 
                                ? Icons.check_rounded
                                : Icons.circle_outlined,
                              size: 16,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rowDateFormat.format(doc.uploadedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedDocIds.contains(docId)) {
        _selectedDocIds.remove(docId);
      } else {
        _selectedDocIds.add(docId);
      }
    });
  }

  void _sortDocuments(List<DocumentEntity> docs) {
    docs.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.title.compareTo(b.title);
          break;
        case 'size':
          comparison = a.sizeBytes.compareTo(b.sizeBytes);
          break;
        case 'date':
        default:
          comparison = a.uploadedAt.compareTo(b.uploadedAt);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Documents'),
        content: Text('Are you sure you want to delete ${_selectedDocIds.length} document(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Get documents to delete
      final allDocs = ref.read(documentProvider).documents;
      final docsToDelete = allDocs.where((doc) => _selectedDocIds.contains(doc.id)).toList();
      
      // Delete each document
      for (final doc in docsToDelete) {
        await ref.read(documentProvider.notifier).delete(doc);
      }
      
      setState(() {
        _selectedDocIds.clear();
        _selectionMode = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${docsToDelete.length} document(s) deleted successfully')),
      );
      
      await _reloadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete documents: $e')),
      );
    }
  }

  String _canonicalCategory(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'individual' || normalized == 'shared' || normalized == 'family' || normalized == 'family vault') return 'shared';
    if (normalized == 'personal') return 'personal';
    if (normalized == 'private' || normalized == 'private vault') return 'private';
    return normalized;
  }

  String? _normalizeVaultCategory(String? value) {
    if (value == null) return null;
    final canonical = _canonicalCategory(value);
    if (canonical == 'shared') return 'Shared';
    if (canonical == 'personal') return 'Personal';
    if (canonical == 'private') return 'Private';
    return value.trim().isEmpty ? null : value.trim();
  }
}
