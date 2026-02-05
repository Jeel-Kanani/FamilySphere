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
  final _typeController = TextEditingController();
  
  List<File> _selectedFiles = [];
  String _selectedCategory = 'Shared'; // Default to Shared to match Vault subsections

  final List<String> _suggestedTypes = [
    'Insurance', 'Medical', 'Legal', 'Tax', 'Home', 'Vehicle', 'Education', 'Other',
  ];

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

              _buildSectionTitle('Vault Section'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCategoryChip('Shared'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Individual'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Private'),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Document Type (Optional)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _suggestedTypes.map((t) => ChoiceChip(
                  label: Text(t),
                  selected: _typeController.text == t,
                  onSelected: (s) => setState(() => _typeController.text = s ? t : ''),
                )).toList(),
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveDocument,
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

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or scan a document first')),
      );
      return;
    }

    try {
      // For now, we upload the first file or handle them sequentially
      for (final file in _selectedFiles) {
        String finalTitle = _titleController.text;
        if (_typeController.text.isNotEmpty) {
          finalTitle += " (${_typeController.text})";
        }

        await ref.read(documentProvider.notifier).upload(
          file: file,
          title: finalTitle,
          category: _selectedCategory,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document(s) saved successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = _selectedCategory == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCategory = label;
          });
        }
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
