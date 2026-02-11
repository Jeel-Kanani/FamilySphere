import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_viewer_screen.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:intl/intl.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const DocumentListScreen({super.key, this.initialCategory});

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
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

  Future<void> _reloadData() async {
    if (_selectedCategory == null) return;
    final notifier = ref.read(documentProvider.notifier);
    final memberId = _categoryScopedMemberId();

    await notifier.loadDocuments(
      category: _selectedCategory,
      folder: _selectedFolder == 'All' ? null : _selectedFolder,
      memberId: memberId,
    );

    notifier.loadFolders(
      category: _selectedCategory!,
      memberId: memberId,
    );
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
    final state = ref.watch(documentProvider);
    final familyState = ref.watch(familyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final docs = state.documents.where((doc) {
      if (_searchController.text.isEmpty) return true;
      return doc.title.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text('${_selectedCategory ?? 'Documents'} Vault'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
        ],
      ),
      body: _buildBody(state.isLoading, docs, familyState, state.folders),
    );
  }

  Widget _buildBody(bool isLoading, List<DocumentEntity> docs, FamilyState familyState, List<String> customFolders) {
    if (_isSearching || _selectedFolder != 'All') {
      return Column(
        children: [
          _buildPathHeader(familyState),
          Expanded(child: _buildDocumentList(isLoading, docs, familyState)),
        ],
      );
    }

    if (_isShared && _selectedMemberId == null) {
      return _buildSharedRoot(familyState, _rootFolders(customFolders));
    }

    if (_isShared && _selectedMemberId != null) {
      return _buildSharedMemberFolders(familyState, _memberFolders(customFolders));
    }

    return _buildTierFolders(_rootFolders(customFolders));
  }

  Widget _buildPathHeader(FamilyState familyState) {
    String label = 'All Documents';
    if (_selectedFolder != 'All') label = _selectedFolder;
    if (_isShared && _selectedMemberId != null) {
      String name = 'Member';
      for (final m in familyState.members) {
        if (m.userId == _selectedMemberId) {
          name = m.displayName;
          break;
        }
      }
      label = '$name / $label';
    }

    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.arrow_back_rounded),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () async {
          setState(() {
            if (_selectedFolder != 'All') {
              _selectedFolder = 'All';
            } else if (_isShared && _selectedMemberId != null) {
              _selectedMemberId = null;
            }
          });
          await _reloadData();
        },
      ),
    );
  }

  Widget _buildSharedRoot(FamilyState familyState, List<String> folders) {
    final members = familyState.members;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.groups_rounded),
          title: const Text('Individual'),
          subtitle: const Text('Open documents member-wise'),
          trailing: Icon(_expandMembers ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _expandMembers = !_expandMembers),
        ),
        if (_expandMembers)
          ...members.map((m) => Padding(
                padding: const EdgeInsets.only(left: 18),
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(m.displayName),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    setState(() {
                      _selectedMemberId = m.userId;
                      _selectedFolder = 'All';
                    });
                    await _reloadData();
                  },
                ),
              )),
        const Divider(height: 20),
        ...folders.map((f) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                setState(() => _selectedFolder = f);
                await _reloadData();
              },
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _createFolderDialog,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Create Folder'),
        ),
      ],
    );
  }

  Widget _buildSharedMemberFolders(FamilyState familyState, List<String> folders) {
    String name = 'Member';
    for (final m in familyState.members) {
      if (m.userId == _selectedMemberId) {
        name = m.displayName;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back_rounded),
          title: Text('$name - Folders'),
          subtitle: const Text('Member-wise document types'),
          onTap: () async {
            setState(() {
              _selectedMemberId = null;
              _selectedFolder = 'All';
            });
            await _reloadData();
          },
        ),
        const Divider(height: 20),
        ...folders.map((f) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                setState(() => _selectedFolder = f);
                await _reloadData();
              },
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _createFolderDialog,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Create Folder'),
        ),
      ],
    );
  }

  Widget _buildTierFolders(List<String> folders) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        ...folders.map((f) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                setState(() => _selectedFolder = f);
                await _reloadData();
              },
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _createFolderDialog,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Create Folder'),
        ),
      ],
    );
  }

  Widget _buildDocumentList(bool isLoading, List<DocumentEntity> docs, FamilyState familyState) {
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
      for (final m in familyState.members) {
        if (m.userId == id) return m.displayName;
      }
      return '';
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final isPdf = doc.fileType.toLowerCase().contains('pdf');
        final ownerName = memberName(doc.memberId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isPdf ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                color: isPdf ? Colors.red : Colors.blue,
                size: 28,
              ),
            ),
            title: Text(
              doc.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _isShared && ownerName.isNotEmpty
                  ? '$ownerName - ${doc.folder} - ${DateFormat('MMM d, y').format(doc.uploadedAt)}'
                  : '${doc.folder} - ${DateFormat('MMM d, y').format(doc.uploadedAt)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
            onTap: () => _openDocument(doc),
          ),
        );
      },
    );
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
