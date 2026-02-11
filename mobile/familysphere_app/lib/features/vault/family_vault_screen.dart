import 'package:flutter/material.dart';

class FamilyVaultScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Family Vault'),
      ),
      body: Center(
        child: Text(
          'No documents in Family Vault',
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