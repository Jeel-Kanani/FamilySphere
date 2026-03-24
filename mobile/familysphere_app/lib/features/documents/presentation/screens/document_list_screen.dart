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
import 'package:familysphere_app/core/utils/routes.dart';
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
  List<String> _currentPath = [];
  String? _selectedMemberId;
  bool _expandMembers = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
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
    // If initialCategory is null, it means "All" (from Home's See All)
    _selectedCategory = widget.initialCategory != null 
        ? _normalizeVaultCategory(widget.initialCategory) 
        : null;

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
    // For "All" view, we fetch everything for the family regardless of memberId constraints
    // (though backend might still enforce some based on familyId)
    return null;
  }

  Future<void> _reloadData({bool reloadFolders = true}) async {
    final notifier = ref.read(documentProvider.notifier);
    final memberId = _categoryScopedMemberId();

    // Use full path for API call
    String? folderParam;
    if (_selectedFolder != 'All') {
      folderParam = [..._currentPath, _selectedFolder].join('/');
    }

    // If _selectedCategory is null, it fetches all documents for the family
    await notifier.loadDocuments(
      category: _selectedCategory,
      folder: folderParam,
      memberId: memberId,
    );

    if (reloadFolders && _selectedCategory != null) {
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

    final fullFolderName = [..._currentPath, folderName].join('/');

    try {
      await ref.read(documentProvider.notifier).createFolder(
            category: _selectedCategory!,
            name: fullFolderName,
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
    List<String> all;
    if (_isShared) {
      all = [..._sharedFolders, ...custom];
    } else if (_isPersonal) {
      all = [..._personalFolders, ...custom];
    } else if (_isPrivate) {
      all = [..._privateFolders, ...custom];
    } else {
      all = custom;
    }
    return _filterHierarchy(all.toSet().toList());
  }

  List<String> _memberFolders(List<String> customFolders) {
    final custom = customFolders.where((f) => f.trim().isNotEmpty).toList();
    return _filterHierarchy([..._memberDocFolders, ...custom].toSet().toList());
  }

  List<String> _filterHierarchy(List<String> folders) {
    final List<String> pathParts = [..._currentPath];
    if (_selectedFolder != 'All') {
      pathParts.add(_selectedFolder);
    }
    final currentPrefix = pathParts.isEmpty ? '' : '${pathParts.join('/')}/';
    final currentPathStr = pathParts.join('/');

    final Set<String> results = {};
    for (final f in folders) {
      if (f.startsWith(currentPrefix) && f != currentPathStr) {
        final relative = f.substring(currentPrefix.length);
        final firstPart = relative.split('/').first;
        if (firstPart.isNotEmpty) {
          results.add(firstPart);
        }
      }
    }
    return results.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(documentProvider.select((s) => s.isLoading));
    final documents = ref.watch(documentProvider.select((s) => s.documents));
    final customFolders = ref.watch(documentProvider.select((s) => s.folders));
    final members = ref.watch(familyProvider.select((s) => s.members));
    final user = ref.watch(authProvider).user;
    final isViewer = user?.isViewer == true;
    final isAdmin = user?.isAdmin == true;
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
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFF0F364E), // Darker teal/navy for CamScanner look
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () {},
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(
                _selectedFolder == 'All' ? 'Doc Scanner' : _selectedFolder,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
        actions: [
          if (!_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700)), // Gold premium icon
              onPressed: () {},
              tooltip: 'Premium',
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white),
              onPressed: () => setState(() => _isSearching = !_isSearching),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (val) {
                if (val == 'trash') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen()));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'import', child: Text('Import from Files')),
                const PopupMenuItem(value: 'sort', child: Text('Sort by')),
                if (!isViewer) const PopupMenuItem(value: 'trash', child: Text('Trash')),
              ],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _selectedDocIds.isEmpty ? null : _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedDocIds.clear();
              }),
            ),
          ],
        ],
      ),
      body: _buildBody(isLoading, docs, members, customFolders, isViewer, isAdmin),
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton.extended(
              onPressed: () {}, // Handled by separate buttons in row
              label: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.scanner,
                      arguments: {
                        'category': _selectedCategory,
                        'folder': [..._currentPath, _selectedFolder].join('/'),
                        'memberId': _categoryScopedMemberId(),
                      },
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.white30),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    onPressed: () => _showAddMenu(),
                  ),
                ],
              ),
              backgroundColor: AppTheme.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
    );
  }

  Widget _buildBody(bool isLoading, List<DocumentEntity> docs, List<FamilyMember> members, List<String> customFolders, bool isViewer, bool isAdmin) {
    if (_isSearching) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPathHeader(members),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
              children: [
                if (docs.isEmpty && !isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No results found', style: TextStyle(color: AppTheme.textTertiary)))),
                ...docs.map((doc) => _buildDocumentItem(doc, members, isViewer)),
                if (isLoading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      );
    }

    if (_isShared && _selectedMemberId == null && _currentPath.isEmpty && _selectedFolder == 'All') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPathHeader(members),
          Expanded(child: _buildSharedRoot(members, _rootFolders(customFolders), isViewer)),
        ],
      );
    }

    final currentFolders = (_isShared && _selectedMemberId != null) 
        ? _memberFolders(customFolders)
        : _rootFolders(customFolders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentPath.isNotEmpty || _selectedFolder != 'All' || (_isShared && _selectedMemberId != null))
          _buildPathHeader(members),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
            children: [
              if (currentFolders.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Folders (${currentFolders.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (!isViewer)
                        IconButton(
                          icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                          onPressed: _createFolderDialog,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
                ...currentFolders.map((f) => _folderTile(f, isViewer)),
                const SizedBox(height: 16),
              ],
              if (docs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'Documents (${docs.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ...docs.map((doc) => _buildDocumentItem(doc, members, isViewer)),
              ] else if (currentFolders.isEmpty && !isLoading)
                _emptyState(),
              if (isLoading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
            ],
          ),
        ),
      ],
    );
  }

  Widget _folderTile(String title, bool isViewer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedFolder != 'All') {
            _currentPath.add(_selectedFolder);
          }
          _selectedFolder = title;
        });
        _reloadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_rounded, color: AppTheme.primaryColor, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Updated Recently', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            if (!isViewer)
              IconButton(
                icon: const Icon(Icons.more_horiz, color: AppTheme.textTertiary),
                onPressed: () => _showFolderOptions(title),
              ),
          ],
        ),
      ),
    );
  }

  void _showFolderOptions(String folderName) {
    final List<String> pathParts = [..._currentPath];
    if (_selectedFolder != 'All') {
      pathParts.add(_selectedFolder);
    }
    final fullPath = pathParts.isEmpty ? folderName : '${pathParts.join('/')}/$folderName';

    final folderDetails = ref.read(documentProvider.notifier).getFolderDetails(
      category: _selectedCategory!,
      memberId: _categoryScopedMemberId(),
    );
    
    final detail = folderDetails?.where((d) => d.name == fullPath).firstOrNull;
    final folderId = detail?.folderId;
    final canDelete = detail?.canDelete ?? true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.folder_rounded, color: Color(0xFF133E59), size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(folderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('Recently Modified', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          if (canDelete) ...[
            _actionListTile(Icons.edit_note_rounded, 'Rename', onTap: () {
              Navigator.pop(context);
              if (folderId != null) _renameFolderDialog(folderName, folderId);
            }),
            _actionListTile(Icons.delete_outline_rounded, 'Delete', color: Colors.red, onTap: () {
              Navigator.pop(context);
              _deleteFolder(folderName, folderId);
            }),
          ] else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Built-in folders cannot be modified', style: TextStyle(color: AppTheme.textTertiary)),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }



  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          children: [
            const Icon(Icons.folder_open_outlined, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('No Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F364E),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('TRY A DEMO DOCUMENT'),
            ),
          ],
        ),
      ),
    );
  }



  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Create New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const Divider(),
          _actionListTile(Icons.create_new_folder_rounded, 'New Folder', onTap: () {
            Navigator.pop(context);
            _createFolderDialog();
          }),
          _actionListTile(Icons.file_upload_rounded, 'Upload File', onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.addDocument, arguments: {
              'category': _selectedCategory,
              'folder': [..._currentPath, _selectedFolder].join('/'),
            });
          }),
          _actionListTile(Icons.camera_alt_rounded, 'Scan Document', onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.scanner, arguments: {
              'category': _selectedCategory,
              'folder': [..._currentPath, _selectedFolder].join('/'),
            });
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _actionListTile(IconData icon, String label, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[700]),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  Widget _buildDocumentItem(DocumentEntity doc, List<FamilyMember> members, bool isViewer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPdf = doc.fileType.toLowerCase().contains('pdf') || doc.fileUrl.toLowerCase().endsWith('.pdf');
    final isSelected = _selectedDocIds.contains(doc.id);

    return InkWell(
      onTap: () => _selectionMode ? _toggleSelection(doc.id) : _openDocument(doc),
      onLongPress: () => setState(() { _selectionMode = true; _selectedDocIds.add(doc.id); }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryColor : AppTheme.primaryColor.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60, height: 75,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: isPdf 
                      ? const Center(child: Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 30))
                      : Image.network(doc.fileUrl, fit: BoxFit.cover, 
                          errorBuilder: (_, __, ___) => const Icon(Icons.description_outlined, color: Colors.grey, size: 30)),
                  ),
                ),
                if (_selectionMode)
                  Positioned(
                    top: 4, left: 4,
                    child: Icon(isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: isSelected ? AppTheme.secondaryColor : Colors.white, size: 20),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(isPdf ? 'PDF' : 'JPG', 
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ),
                      const SizedBox(width: 8),
                      Text('${doc.fileSizeString}  ${_rowDateFormat.format(doc.uploadedAt)}',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                  if (doc.ocrStatus == 'needs_confirmation') ...[  
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline_rounded, size: 11, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text('Needs Confirmation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isViewer)
              IconButton(
                icon: const Icon(Icons.more_horiz, color: AppTheme.textTertiary),
                onPressed: () {}, // TODO: Implement document actions menu
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildPathHeader(List<FamilyMember> members) {
    String categoryName = _selectedCategory ?? 'Vault';

    List<Widget> breadcrumbs = [];

    // Category
    breadcrumbs.add(
      _breadcrumbItem(categoryName, true, () {
        setState(() {
          _currentPath = [];
          _selectedFolder = 'All';
          _selectedMemberId = null;
        });
        _reloadData();
      }),
    );

    // Member (if shared)
    if (_isShared && _selectedMemberId != null) {
      String name = 'Member';
      for (final m in members) {
        if (m.userId == _selectedMemberId) {
          name = m.displayName;
          break;
        }
      }
      breadcrumbs.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('>', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13, fontWeight: FontWeight.bold)),
      ));
      breadcrumbs.add(
        _breadcrumbItem(name, false, () {
          setState(() {
            _currentPath = [];
            _selectedFolder = 'All';
          });
          _reloadData();
        }),
      );
    }

    // Paths
    for (int i = 0; i < _currentPath.length; i++) {
      final part = _currentPath[i];
      breadcrumbs.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('>', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13, fontWeight: FontWeight.bold)),
      ));
      breadcrumbs.add(
        _breadcrumbItem(part, false, () {
          setState(() {
            _currentPath = _currentPath.sublist(0, i);
            _selectedFolder = part;
          });
          _reloadData();
        }),
      );
    }

    // Current Folder (if not All)
    if (_selectedFolder != 'All') {
      breadcrumbs.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('>', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13, fontWeight: FontWeight.bold)),
      ));
      breadcrumbs.add(
        Text(
          _selectedFolder,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (_selectedFolder != 'All' || _currentPath.isNotEmpty || (_isShared && _selectedMemberId != null))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedFolder != 'All') {
                          if (_currentPath.isNotEmpty) {
                            _selectedFolder = _currentPath.last;
                            _currentPath.removeLast();
                          } else {
                            _selectedFolder = 'All';
                          }
                        } else if (_isShared && _selectedMemberId != null) {
                          _selectedMemberId = null;
                        }
                      });
                      _reloadData();
                    },
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ...breadcrumbs,
          ],
        ),
      ),
    );
  }

  Widget _breadcrumbItem(String label, bool isRoot, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRoot) ...[
              const Icon(Icons.grid_view_rounded, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nodeTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? imageUrl,
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
              color: isDark ? AppTheme.darkBorder : AppTheme.primaryColor.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                  color: effectiveIconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(icon, color: effectiveIconColor, size: 24),
                        ),
                      )
                    : Icon(icon, color: effectiveIconColor, size: 24),
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
        folderId: folderId ?? 'builtin',
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

  Widget _buildSharedRoot(List<FamilyMember> members, List<String> folders, bool isViewer) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
      children: [
        _nodeTile(
          icon: Icons.groups_rounded,
          title: 'Individual Folders',
          subtitle: _expandMembers ? 'Tap to collapse' : 'Tap to expand member list',
          onTap: () => setState(() => _expandMembers = !_expandMembers),
          iconColor: const Color(0xFF0EA5E9),
        ),
        if (_expandMembers)
          ...members.map((m) => _nodeTile(
                icon: Icons.person_outline_rounded,
                imageUrl: m.photoUrl,
                title: m.displayName,
                subtitle: 'View specific documents',
                leftPad: 14,
                onTap: () async {
                  setState(() {
                    _selectedMemberId = m.userId;
                    _selectedFolder = 'All';
                  });
                  await _reloadData(reloadFolders: true);
                },
              )),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'General Shared Folders (${folders.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ...folders.map((f) => _folderTile(f, isViewer)),
        const SizedBox(height: 12),
        if (!isViewer)
          OutlinedButton.icon(
            onPressed: _createFolderDialog,
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            label: const Text('Create Shared Folder'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  // Legacy document list logic removed in favor of mapping inside _buildBody

  // Legacy methods removed in favor of unified view


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
      final allDocs = ref.read(documentProvider).documents;
      final docsToDelete = allDocs.where((doc) => _selectedDocIds.contains(doc.id)).toList();
      
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
