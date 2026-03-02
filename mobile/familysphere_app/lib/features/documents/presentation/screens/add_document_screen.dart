import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/family/domain/entities/family_member.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';
import 'package:familysphere_app/features/documents/presentation/widgets/premium_upload_overlay.dart';

class AddDocumentScreen extends ConsumerStatefulWidget {
  final List<String>? initialImagePaths;
  final String? initialCategory;
  final String? initialFolder;
  final String? initialMemberId;

  const AddDocumentScreen({
    super.key,
    this.initialImagePaths,
    this.initialCategory,
    this.initialFolder,
    this.initialMemberId,
  });

  @override
  ConsumerState<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  static const Map<String, List<String>> _builtInByCategory = {
    'Shared': ['Property Deed', 'Medical', 'Insurance', 'Vehicle', 'Finance & Tax', 'Legal', 'Education', 'Household Bills'],
    'Personal': ['Study & Learning', 'Career Documents', 'Business', 'Portfolio', 'Personal Certificates', 'Creative Work', 'Travel', 'Misc Personal'],
    'Private': ['Passwords', 'Confidential Notes', 'Legal Contracts', 'Bank Accounts', 'Identity Secrets', 'Recovery Keys', 'Private Finance', 'Critical Credentials'],
  };

  static const List<String> _sharedMemberFolders = [
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

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _typeController = TextEditingController();

  List<File> _selectedFiles = [];
  String _selectedCategory = 'Shared';
  String _selectedFolder = 'Property Deed';
  String? _selectedMemberId;
  // OCR is now handled in the background, _pendingOcrDocId is removed

  bool _showPremiumOverlay = false;
  final GlobalKey<PremiumUploadOverlayState> _overlayKey = GlobalKey<PremiumUploadOverlayState>();

  final List<String> _suggestedTypes = ['Insurance', 'Medical', 'Legal', 'Tax', 'Home', 'Vehicle', 'Education', 'Other'];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'Shared';
    _selectedFolder = widget.initialFolder ??
        (_builtInByCategory[_selectedCategory] ?? const ['General']).first;
    _selectedMemberId = widget.initialMemberId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(documentProvider.notifier)
          .loadFolders(category: _selectedCategory, memberId: _selectedMemberId);
      ref.read(familyProvider.notifier).loadFamily().then((_) {
        if (!mounted) return;
        if (widget.initialMemberId == null && widget.initialCategory == null) {
          if (_selectedCategory == 'Shared') {
            setState(() => _selectedMemberId = null);
          } else {
            setState(() => _selectedMemberId = ref.read(authProvider).user?.id);
          }
        }
      });
    });

    if (widget.initialImagePaths != null) {
      _selectedFiles = widget.initialImagePaths!.map(File.new).toList();
      if (_selectedFiles.isNotEmpty) {
        _titleController.text = 'Doc_${DateTime.now().millisecondsSinceEpoch}';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files.where((f) => f.path != null).map((f) => File(f.path!)));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File pick failed: $e')));
    }
  }

  Future<void> _scanDoc() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.scanner,
      arguments: {
        'returnOnly': true,
        'category': _selectedCategory,
        'folder': _selectedFolder,
        'memberId': _selectedMemberId,
      },
    );
    if (result != null && result is List<String>) {
      setState(() {
        _selectedFiles.addAll(result.map(File.new));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(documentProvider.select((s) => s.isLoading));
    final folders = ref.watch(documentProvider.select((s) => s.folders));
    final members = ref.watch(familyProvider.select((s) => s.members));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Upload to Vault'),
        elevation: 0,
        actions: [
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedFiles.length} file${_selectedFiles.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Indicator
              _buildStepIndicator(),
              const SizedBox(height: 20),
              
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.file_upload_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Files',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_selectedFiles.isNotEmpty)
                      _buildFilesGrid()
                    else
                      _buildSourceButtons(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_document,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Document Details',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      enabled: !isLoading,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Document Title',
                        hintText: 'Enter a descriptive title',
                        prefixIcon: const Icon(Icons.title_rounded),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceVariant.withOpacity(0.5)
                            : const Color(0xFFF8FAFC),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Please enter a title'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Vault category dropdown ─────────────────────────
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Vault Category',
                        prefixIcon: Icon(
                          _categoryIcon(_selectedCategory),
                          color: _categoryColor(_selectedCategory),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceVariant.withOpacity(0.5)
                            : const Color(0xFFF8FAFC),
                      ),
                      items: ['Shared', 'Personal', 'Private'].map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _categoryColor(cat),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(cat),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: isLoading
                          ? null
                          : (value) {
                              if (value == null) return;
                              final defaultMemberId = value == 'Shared'
                                  ? null
                                  : ref.read(authProvider).user?.id;
                              setState(() {
                                _selectedCategory = value;
                                _selectedFolder =
                                    (_builtInByCategory[value] ??
                                            const ['General'])
                                        .first;
                                _selectedMemberId = defaultMemberId;
                              });
                              ref
                                  .read(documentProvider.notifier)
                                  .loadFolders(
                                    category: value,
                                    memberId: value == 'Shared'
                                        ? _selectedMemberId
                                        : ref
                                            .read(authProvider)
                                            .user
                                            ?.id,
                                  );
                            },
                    ),

                    // ── Share With dropdown (Shared only) ────────────────
                    if (_selectedCategory == 'Shared') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedMemberId ?? '__family__',
                        decoration: InputDecoration(
                          labelText: 'Share With',
                          prefixIcon: const Icon(Icons.groups_rounded),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceVariant.withOpacity(0.5)
                              : const Color(0xFFF8FAFC),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '__family__',
                            child: Row(
                              children: [
                                Icon(Icons.groups_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Entire Family'),
                              ],
                            ),
                          ),
                          ...members.map((m) => DropdownMenuItem<String>(
                                value: m.userId,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: AppTheme.primaryColor
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        _initials(m.displayName),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(m.displayName),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) {
                                if (value == null) return;
                                final memberId =
                                    value == '__family__' ? null : value;
                                setState(() {
                                  _selectedMemberId = memberId;
                                  _selectedFolder = memberId == null
                                      ? (_builtInByCategory['Shared'] ??
                                              const ['General'])
                                          .first
                                      : _sharedMemberFolders.first;
                                });
                                ref
                                    .read(documentProvider.notifier)
                                    .loadFolders(
                                        category: 'Shared',
                                        memberId: memberId);
                              },
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Folder dropdown ──────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: _currentFolderSelection(folders),
                      decoration: InputDecoration(
                        labelText: 'Folder',
                        hintText: 'Select a folder',
                        prefixIcon: const Icon(Icons.folder_outlined),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceVariant.withOpacity(0.5)
                            : const Color(0xFFF8FAFC),
                      ),
                      items: _folderOptions(folders)
                          .map((f) => DropdownMenuItem<String>(
                                value: f,
                                child: Text(f),
                              ))
                          .toList(),
                      onChanged: isLoading
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _selectedFolder = value);
                            },
                    ),
                    const SizedBox(height: 16),

                    // ── Document Type dropdown ───────────────────────────
                    DropdownButtonFormField<String>(
                      value: _typeController.text.isEmpty
                          ? null
                          : _typeController.text,
                      decoration: InputDecoration(
                        labelText: 'Document Type (Optional)',
                        hintText: 'Select a type',
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceVariant.withOpacity(0.5)
                            : const Color(0xFFF8FAFC),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._suggestedTypes.map((t) =>
                            DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            )),
                      ],
                      onChanged: isLoading
                          ? null
                          : (value) => setState(
                              () => _typeController.text = value ?? ''),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
          if (_showPremiumOverlay)
            PremiumUploadOverlay(
              key: _overlayKey,
              onComplete: () {
                if (mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Documents secured in Vault ✨'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, isLoading, isDark),
    );
  }

  Widget _buildStepIndicator() {
    final hasFiles = _selectedFiles.isNotEmpty;
    final hasTitle = _titleController.text.isNotEmpty;
    final step = hasTitle ? 3 : hasFiles ? 2 : 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final labels = ['Select Files', 'Document Details', 'Save'];
    final icons = [
      Icons.upload_file_rounded,
      Icons.edit_document,
      Icons.cloud_done_rounded,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isCompleted = i + 1 < step;
          final isActive = i + 1 == step;
          final color = isCompleted || isActive
              ? AppTheme.primaryColor
              : (isDark ? Colors.white24 : AppTheme.borderColor);

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppTheme.primaryColor
                              : isActive
                                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFF1F5F9)),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.8),
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16)
                              : Icon(icons[i],
                                  color: isActive
                                      ? AppTheme.primaryColor
                                      : (isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8)),
                                  size: 16),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? AppTheme.primaryColor
                              : (isDark ? Colors.white38 : AppTheme.textSecondary),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCompleted
                              ? [AppTheme.primaryColor, AppTheme.primaryColor]
                              : [
                                  isActive
                                      ? AppTheme.primaryColor
                                          .withValues(alpha: 0.4)
                                      : (isDark
                                          ? Colors.white12
                                          : AppTheme.borderColor),
                                  isDark ? Colors.white12 : AppTheme.borderColor,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // _buildStepDot and _buildStepLine replaced by _buildStepIndicator above

  Widget _buildSourceButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Primary: pick from device ──────────────────────────────────
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  const Color(0xFF3B82F6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_rounded,
                    color: Colors.white, size: 32),
                SizedBox(width: 14),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload from Device',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'PDF, JPG, PNG supported',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Divider with "or" ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? Colors.white12 : AppTheme.borderColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white38
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? Colors.white12 : AppTheme.borderColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Secondary: scan with camera ────────────────────────────────
        GestureDetector(
          onTap: _scanDoc,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : AppTheme.borderColor,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Scan with Camera',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.87)
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color:
                      isDark ? Colors.white38 : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isLoading, bool isDark) {
    final canSave = _selectedFiles.isNotEmpty && !isLoading;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
            top: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: canSave ? _saveDocument : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: canSave ? AppTheme.primaryGradient : null,
            color: canSave ? null : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: canSave
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        color: canSave ? Colors.white : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedFiles.isEmpty
                            ? 'Select files to continue'
                            : 'Save to Vault',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: canSave
                              ? Colors.white
                              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
                      if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedFiles.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.primaryColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 32),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ChoiceChip _categoryChip(String label) {
    final isSelected = _selectedCategory == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) {
        if (!selected) return;
        final defaultMemberId = label == 'Shared' ? null : ref.read(authProvider).user?.id;
        setState(() {
          _selectedCategory = label;
          _selectedFolder = (_builtInByCategory[label] ?? const ['General']).first;
          _selectedMemberId = defaultMemberId;
        });
        ref.read(documentProvider.notifier).loadFolders(
              category: label,
              memberId: label == 'Shared' ? _selectedMemberId : ref.read(authProvider).user?.id,
            );
      },
    );
  }

  Widget _buildFilesGrid() {
    final cacheWidth = (95 * MediaQuery.devicePixelRatioOf(context)).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected Files',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedFiles.clear()),
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length + 1,
              itemBuilder: (context, index) {
                if (index == _selectedFiles.length) {
                  return Container(
                    width: 95,
                    margin: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.1),
                              AppTheme.primaryColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: AppTheme.primaryColor,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add More',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Container(
                  width: 95,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.borderColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _filePreviewTile(_selectedFiles[index], cacheWidth),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => setState(() => _selectedFiles.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _filePreviewTile(File file, int cacheWidth) {
    if (_isImageFile(file.path)) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.low,
      );
    }

    final isPdf = _isPdfFile(file.path);
    return Container(
      color: isPdf ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              color: isPdf ? Colors.red : AppTheme.textSecondary,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              isPdf ? 'PDF' : 'FILE',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPdfFile(String path) => path.toLowerCase().endsWith('.pdf');

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _uploadPathLabel(List<FamilyMember> members) {
    if (_selectedCategory != 'Shared') {
      return '$_selectedCategory / $_selectedFolder';
    }

    if (_selectedMemberId == null) {
      return 'Shared / Family / $_selectedFolder';
    }

    String memberName = 'Member';
    for (final m in members) {
      if (m.userId == _selectedMemberId) {
        memberName = m.displayName;
        break;
      }
    }
    return 'Shared / Individual / $memberName / $_selectedFolder';
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Shared': return Icons.groups_rounded;
      case 'Personal': return Icons.person_rounded;
      case 'Private': return Icons.lock_rounded;
      default: return Icons.folder_rounded;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Shared': return AppTheme.primaryColor;
      case 'Personal': return const Color(0xFF8B5CF6);
      case 'Private': return const Color(0xFFEF4444);
      default: return AppTheme.primaryColor;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _currentFolderSelection(List<String> folders) {
    final options = _folderOptions(folders);
    return options.contains(_selectedFolder) ? _selectedFolder : options.first;
  }

  List<String> _folderOptions(List<String> folders) {
    final builtIn = _selectedCategory == 'Shared' && _selectedMemberId != null
        ? _sharedMemberFolders
        : (_builtInByCategory[_selectedCategory] ?? const <String>[]);

    final merged = <String>{...builtIn, 'General'};
    for (final folder in folders) {
      final trimmed = folder.trim();
      if (trimmed.isNotEmpty) merged.add(trimmed);
    }
    return merged.toList();
  }

  // OCR polling removed as it now happens in the background.

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or scan a document first')));
      return;
    }

    final validFolders = _folderOptions(ref.read(documentProvider).folders);
    if (!validFolders.contains(_selectedFolder)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid folder for selected vault path. Please reselect folder.')),
      );
      return;
    }
    try {
      setState(() => _showPremiumOverlay = true);

      for (final file in _selectedFiles) {
        var finalTitle = _titleController.text.trim();
        if (_typeController.text.isNotEmpty) {
          finalTitle += ' (${_typeController.text})';
        }

        await ref.read(documentProvider.notifier).upload(
              file: file,
              title: finalTitle,
              category: _selectedCategory,
              folder: _selectedFolder,
              memberId: _selectedCategory == 'Shared' ? _selectedMemberId : ref.read(authProvider).user?.id,
            );
      }

      // Start the "Deposit" animation phase once upload is complete
      _overlayKey.currentState?.startDeposit();
    } catch (e) {
      if (mounted) setState(() => _showPremiumOverlay = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }
}
