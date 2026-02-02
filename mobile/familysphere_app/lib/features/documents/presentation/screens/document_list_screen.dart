import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_viewer_screen.dart';
import 'package:intl/intl.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key});

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _categories = [
    'All', 'Insurance', 'Medical', 'Legal', 'Tax', 'Home', 'Vehicle', 'Education', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentProvider.notifier).loadDocuments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: document)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredDocs = state.documents.where((doc) {
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
              onChanged: (val) => setState(() {}),
            )
          : const Text('Documents'),
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
      body: Column(
        children: [
          _buildCategorySelector(),
          Expanded(
            child: _buildDocumentList(state.isLoading, filteredDocs),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            selectedColor: AppTheme.primaryColor,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            showCheckmark: false,
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentList(bool isLoading, List<DocumentEntity> docs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isLoading && docs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textTertiary.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('No documents found', style: TextStyle(color: AppTheme.textTertiary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final isPdf = doc.fileType == 'pdf';
        
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
            ),
            subtitle: Text(
              '${doc.category} • ${DateFormat('MMM d, y').format(doc.uploadedAt)}',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
            onTap: () => _openDocument(doc),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textTertiary),
          ),
        );
      },
    );
  }
}
