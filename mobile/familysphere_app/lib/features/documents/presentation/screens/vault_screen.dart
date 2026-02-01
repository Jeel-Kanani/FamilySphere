import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Vault'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTierHeader('Tier 1: Global Family Vault'),
            const SizedBox(height: 12),
            _buildVaultCard(
              context,
              title: 'Common Documents',
              subtitle: 'Property, Taxes, Utility Bills',
              icon: Icons.family_restroom,
              color: Colors.blue,
              tags: ['Gas', 'Water', 'Electricity', 'Property'],
            ),
            
            const SizedBox(height: 24),
            
            _buildTierHeader('Tier 2: Member Wise Necessity'),
            const SizedBox(height: 12),
            _buildVaultCard(
              context,
              title: 'Family Members',
              subtitle: 'IDs, Education, Medical Records',
              icon: Icons.people_outline,
              color: Colors.green,
              tags: ['Aadhaar', 'Degree', 'Health', 'Travel'],
            ),
            
            const SizedBox(height: 24),
            
            _buildTierHeader('Tier 3: Personal Locker'),
            const SizedBox(height: 12),
            _buildVaultCard(
              context,
              title: 'Private Vault',
              subtitle: 'Only visible to you',
              icon: Icons.lock_outline,
              color: Colors.orange,
              isLocked: true,
              tags: ['Private Photos', 'Study Material', 'Finance'],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-document'),
        label: const Text('Add Document'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTierHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVaultCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> tags,
    bool isLocked = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withValues(alpha: 0.1)),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.08),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  const Icon(Icons.fingerprint, color: Colors.orange, size: 20)
                else
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.1)),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
