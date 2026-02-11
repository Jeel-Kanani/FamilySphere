import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'widgets/search_bar_widget.dart';
import 'document_preview_screen.dart';

class PrivateVaultScreen extends StatefulWidget {
  @override
  _PrivateVaultScreenState createState() => _PrivateVaultScreenState();
}

class _PrivateVaultScreenState extends State<PrivateVaultScreen> {
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
        Uri.parse('http://10.0.2.2:5000/api/documents'), // Replace with baseUrl
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
        return title.contains(query.toLowerCase()) || category.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Private Vault'),
      ),
      body: Column(
        children: [
          SearchBarWidget(onSearch: filterDocuments),
          Expanded(
            child: filteredDocuments.isEmpty
                ? Center(
                    child: Text(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // TODO: Implement upload functionality
        },
        child: Icon(Icons.add),
      ),
    );
  }
}