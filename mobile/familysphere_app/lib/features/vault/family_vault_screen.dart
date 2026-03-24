import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FamilyVaultScreen extends ConsumerStatefulWidget {
  const FamilyVaultScreen({super.key});

  @override
  ConsumerState<FamilyVaultScreen> createState() => _FamilyVaultScreenState();
}

class _FamilyVaultScreenState extends ConsumerState<FamilyVaultScreen> {
  @override
  Widget build(BuildContext context) {
    final isViewer = ref.watch(authProvider.select((state) => state.user?.isViewer == true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Vault'),
      ),
      body: const Center(
        child: Text(
          'No documents in Family Vault',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton(
              onPressed: () {
                // TODO: Implement add document functionality
              },
              tooltip: 'Add document',
              child: const Icon(Icons.add),
            ),
    );
  }
}
