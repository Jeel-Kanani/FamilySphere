import 'dart:convert';
import 'package:familysphere_app/core/config/api_config.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/vault/document_preview_screen.dart';
import 'package:familysphere_app/features/vault/widgets/search_bar_widget.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivateVaultScreen extends ConsumerStatefulWidget {
  const PrivateVaultScreen({super.key});

  @override
  ConsumerState<PrivateVaultScreen> createState() => _PrivateVaultScreenState();
}

class _PrivateVaultScreenState extends ConsumerState<PrivateVaultScreen> {
  List<dynamic> documents = [];
  List<dynamic> filteredDocuments = [];
  
  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getDocumentsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          documents = json.decode(response.body);
        });
      } else {
        print('Failed to fetch documents: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching documents: $e');
    }
  }

  void filterDocuments(String query) {
    setState(() {
      filteredDocuments = documents.where((doc) {
        final title = doc['title']?.toLowerCase() ?? '';
        final category = doc['category']?.toLowerCase() ?? '';
        return title.contains(query.toLowerCase()) ||
            category.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isViewer = ref.watch(authProvider.select((state) => state.user?.isViewer == true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Vault'),
      ),
      body: Column(
        children: [
          SearchBarWidget(onSearch: filterDocuments),
          Expanded(
            child: filteredDocuments.isEmpty
                ? Center(
                    child: const Text(
                      'No documents found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final document = filteredDocuments[index];
                      return ListTile(
                        title: Text(document['title'] ?? 'Untitled'),
                        subtitle: Text(document['category'] ?? 'No category'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocumentPreviewScreen(
                                documentUrl: document['fileUrl'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton(
              onPressed: () async {
                // TODO: Implement upload functionality
              },
              tooltip: 'Upload document',
              child: const Icon(Icons.add),
            ),
    );
  }
}
