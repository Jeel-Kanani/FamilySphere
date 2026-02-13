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

class AddDocumentScreen extends ConsumerStatefulWidget {
  final List<String>? initialImagePaths;
  const AddDocumentScreen({super.key, this.initialImagePaths});

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

  final List<String> _suggestedTypes = ['Insurance', 'Medical', 'Legal', 'Tax', 'Home', 'Vehicle', 'Education', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentProvider.notifier).loadFolders(category: _selectedCategory);
      ref.read(familyProvider.notifier).loadFamily().then((_) {
        if (!mounted) return;
        if (_selectedCategory == 'Shared') {
          setState(() => _selectedMemberId = null);
        } else {
          setState(() => _selectedMemberId = ref.read(authProvider).user?.id);
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
      arguments: const {'returnOnly': true},
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
      body: SingleChildScrollView(
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
                      decoration: InputDecoration(
                        labelText: 'Document Title',
                        hintText: 'Enter a descriptive title',
                        prefixIcon: const Icon(Icons.title_rounded),
                        filled: true,
                        fillColor: isDark 
                          ? AppTheme.darkSurfaceVariant.withOpacity(0.5)
                          : const Color(0xFFF8FAFC),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) 
                        ? 'Please enter a title' 
                        : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vault Location',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Shared', 'Personal', 'Private'].map(_categoryChip).toList(),
                    ),
                    if (_selectedCategory == 'Shared') ...[
                      const SizedBox(height: 16),
                      Text(
                        'Share With',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: members.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return ChoiceChip(
                                avatar: const Icon(Icons.groups_rounded, size: 16),
                                label: const Text('Family'),
                                selected: _selectedMemberId == null,
                                showCheckmark: false,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedMemberId = null;
                                    _selectedFolder = (_builtInByCategory['Shared'] ?? const ['General']).first;
                                  });
                                  ref.read(documentProvider.notifier).loadFolders(category: 'Shared', memberId: null);
                                },
                              );
                            }
                            final m = members[i - 1];
                            return ChoiceChip(
                              avatar: const Icon(Icons.person_rounded, size: 16),
                              label: Text(m.displayName),
                              selected: _selectedMemberId == m.userId,
                              showCheckmark: false,
                              onSelected: (_) {
                                setState(() {
                                  _selectedMemberId = m.userId;
                                  _selectedFolder = _sharedMemberFolders.first;
                                });
                                ref.read(documentProvider.notifier).loadFolders(category: 'Shared', memberId: m.userId);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_special_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Upload Path',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _uploadPathLabel(members),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Document Type (Optional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedTypes
                          .map((t) => ChoiceChip(
                                label: Text(t),
                                selected: _typeController.text == t,
                                onSelected: (s) => setState(() => _typeController.text = s ? t : ''),
                                showCheckmark: false,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, isLoading, isDark),
    );
  }

  Widget _buildStepIndicator() {
    final hasFiles = _selectedFiles.isNotEmpty;
    final hasTitle = _titleController.text.isNotEmpty;
    
    return Row(
      children: [
        _buildStepDot(1, true, hasFiles),
        Expanded(child: _buildStepLine(hasFiles)),
        _buildStepDot(2, hasFiles, hasTitle),
        Expanded(child: _buildStepLine(hasTitle)),
        _buildStepDot(3, hasTitle, false),
      ],
    );
  }

  Widget _buildStepDot(int step, bool isActive, bool isCompleted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted || isActive
          ? AppTheme.primaryColor
          : (isDark ? AppTheme.darkSurface : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted || isActive
            ? AppTheme.primaryColor
            : AppTheme.borderColor,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Container(
      height: 2,
      color: isCompleted
        ? AppTheme.primaryColor
        : AppTheme.borderColor,
    );
  }

  Widget _buildSourceButtons() {
    return Row(
      children: [
        Expanded(
          child: _sourceButton(
            icon: Icons.cloud_upload_rounded,
            label: 'Upload Files',
            subtitle: 'PDF, Images',
            onTap: _pickFile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _sourceButton(
            icon: Icons.document_scanner_rounded,
            label: 'Scan Document',
            subtitle: 'Use Camera',
            onTap: _scanDoc,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isLoading, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading || _selectedFiles.isEmpty ? null : _saveDocument,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_done_rounded),
                    const SizedBox(width: 8),
                    const Text('Save to Vault'),
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedFiles.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document(s) saved successfully')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }
}
