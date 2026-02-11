import 'package:flutter/material.dart';

class VaultScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vault', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          _buildVaultSection(context, 'Private Vault', Icons.lock, Colors.blue),
          SizedBox(height: 16),
          _buildVaultSection(context, 'Shared Vault', Icons.group, Colors.green),
          SizedBox(height: 16),
          _buildVaultSection(context, 'Family Vault', Icons.family_restroom, Colors.orange),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement scan/upload functionality
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildVaultSection(BuildContext context, String title, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 40, color: color),
        title: Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // TODO: Navigate to respective vault screen
        },
      ),
    );
  }
}