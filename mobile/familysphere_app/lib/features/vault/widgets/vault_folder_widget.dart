import 'package:flutter/material.dart';

class VaultFolderWidget extends StatelessWidget {
  final String folderName;
  final VoidCallback onTap;

  const VaultFolderWidget({
    required this.folderName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.folder, size: 40, color: Colors.blue),
              SizedBox(width: 16),
              Text(
                folderName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}