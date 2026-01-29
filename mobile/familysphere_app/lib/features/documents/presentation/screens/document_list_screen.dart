import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/screens/add_document_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_viewer_screen.dart';
import 'package:intl/intl.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key});

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  String? _selectedCategory;

  final List<String> _categories = [
    'All',
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentProvider.notifier).loadDocuments();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category == 'All' ? null : category;
    });
    ref.read(documentProvider.notifier).loadDocuments(category: _selectedCategory);
  }

  void _openDocument(DocumentEntity document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(document: document),
      ),
    );
  }

  Future<void> _deleteDocument(DocumentEntity document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(documentProvider.notifier).delete(document);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDocumentScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Category Selector
          SizedBox(
            height: 60,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = (category == 'All' && _selectedCategory == null) ||
                    category == _selectedCategory;
                
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => _onCategorySelected(category),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              },
            ),
          ),

          // Document List
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No documents found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.documents.length,
                        itemBuilder: (context, index) {
                          final doc = state.documents[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: doc.fileType == 'pdf' 
                                      ? Colors.red.shade50 
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  doc.fileType == 'pdf' 
                                      ? Icons.picture_as_pdf 
                                      : Icons.image,
                                  color: doc.fileType == 'pdf' 
                                      ? Colors.red 
                                      : Colors.blue,
                                ),
                              ),
                              title: Text(
                                doc.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${doc.category} • ${DateFormat('MMM d, y').format(doc.uploadedAt)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    doc.fileSizeString,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                              onTap: () => _openDocument(doc),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'download',
                                    child: Row(
                                      children: [
                                        Icon(Icons.download, size: 20),
                                        SizedBox(width: 8),
                                        Text('Download'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteDocument(doc);
                                  } else if (value == 'download') {
                                    ref.read(documentProvider.notifier).download(doc);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Download started...')),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
