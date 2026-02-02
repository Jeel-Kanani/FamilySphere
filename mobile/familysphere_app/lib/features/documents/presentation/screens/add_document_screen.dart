import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';

class AddDocumentScreen extends ConsumerStatefulWidget {
  final List<String>? initialImagePaths;
  const AddDocumentScreen({super.key, this.initialImagePaths});

  @override
  ConsumerState<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  
  List<File> _selectedFiles = [];
  String _selectedTier = 'Global';
  String _selectedFolder = 'None';

  final List<String> _suggestedCategories = [
    'Insurance', 'Medical', 'Legal', 'Tax', 'Home', 'Vehicle', 'Education', 'Other',
  ];

  final List<String> _tiers = ['Global', 'Member-wise', 'Private'];
  final List<String> _folders = ['None', 'Taxes 2023', 'Rental Agreements', 'Vehicle Docs', 'Medical Reports'];

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePaths != null) {
      _selectedFiles = widget.initialImagePaths!.map((p) => File(p)).toList();
      if (_selectedFiles.isNotEmpty) {
        _titleController.text = 'Doc_${DateTime.now().millisecondsSinceEpoch}';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _scanDoc() async {
    final result = await Navigator.pushNamed(context, '/scanner');
    if (result != null && result is List<String>) {
      setState(() {
        _selectedFiles.addAll(result.map((p) => File(p)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Save Document'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Multiple Files Preview
              if (_selectedFiles.isNotEmpty)
                _buildFilesGrid()
              else
                Row(
                  children: [
                    Expanded(child: _buildSourceCard(icon: Icons.cloud_upload_outlined, label: 'Upload', onTap: _pickFile)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSourceCard(icon: Icons.document_scanner_outlined, label: 'Scan', onTap: _scanDoc)),
                  ],
                ),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Document Details'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Document Title', prefixIcon: Icon(Icons.title)),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a title' : null,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Tier'),
                        const SizedBox(height: 8),
                        _buildDropdown(_selectedTier, _tiers, (val) => setState(() => _selectedTier = val!)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Folder'),
                        const SizedBox(height: 8),
                        _buildDropdown(_selectedFolder, _folders, (val) => setState(() => _selectedFolder = val!)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _suggestedCategories.map((c) => ChoiceChip(
                  label: Text(c),
                  selected: _categoryController.text == c,
                  onSelected: (s) => setState(() => _categoryController.text = s ? c : ''),
                )).toList(),
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save to Vault', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilesGrid() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedFiles.length) {
            return GestureDetector(
              onTap: _scanDoc,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.none)),
                child: const Icon(Icons.add_a_photo, color: Colors.grey),
              ),
            );
          }
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: FileImage(_selectedFiles[index]), fit: BoxFit.cover),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const CircleAvatar(backgroundColor: Colors.black54, radius: 10, child: Icon(Icons.close, size: 12, color: Colors.white)),
                onPressed: () => setState(() => _selectedFiles.removeAt(index)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87));

  Widget _buildSourceCard({required IconData icon, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [Icon(icon, color: AppTheme.primaryColor, size: 32), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w600))]),
      ),
    );
  }
}
