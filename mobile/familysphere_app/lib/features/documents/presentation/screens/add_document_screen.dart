import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';

class AddDocumentScreen extends ConsumerStatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  ConsumerState<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(); // Simple text input for now, could be dropdown
  
  File? _selectedFile;
  String? _fileName;
  String? _fileSize;

  final List<String> _suggestedCategories = [
    'Insurance',
    'Medical',
    'Legal',
    'Tax',
    'Home',
    'Vehicle',
    'Education',
    'Other',
  ];

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
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final size = await file.length();
        
        setState(() {
          _selectedFile = file;
          _fileName = result.files.single.name;
          _fileSize = _formatSize(size);
          // Auto-fill title if empty
          if (_titleController.text.isEmpty) {
            _titleController.text = _fileName!.split('.').first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    try {
      await ref.read(documentProvider.notifier).upload(
        file: _selectedFile!,
        title: _titleController.text.trim(),
        category: _categoryController.text.trim().isEmpty 
            ? 'Other' 
            : _categoryController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Document'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File Selection Area
              GestureDetector(
                onTap: isLoading ? null : _pickFile,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedFile != null ? AppTheme.primaryColor : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: _selectedFile != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _fileName!.endsWith('.pdf') 
                                  ? Icons.picture_as_pdf 
                                  : Icons.image,
                              size: 48,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _fileName!,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _fileSize!,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to change',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select a file',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PDF, JPG, PNG',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Document Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              
              // Category Field with Suggestions
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                  hintText: 'e.g., Insurance, Medical',
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              
              // Category Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedCategories.map((category) {
                  return ActionChip(
                    label: Text(category),
                    onPressed: isLoading ? null : () {
                      _categoryController.text = category;
                    },
                    backgroundColor: Colors.grey.shade100,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 32),
              
              // Upload Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Upload Document',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
