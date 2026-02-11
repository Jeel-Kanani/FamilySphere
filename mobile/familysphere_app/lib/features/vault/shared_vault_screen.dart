import 'package:flutter/material.dart';

class SharedVaultScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shared Vault'),
      ),
      body: Center(
        child: Text(
          'No documents in Shared Vault',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement add document functionality
        },
        child: Icon(Icons.add),
      ),
    );
  }
}