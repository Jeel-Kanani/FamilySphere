import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedVaultScreen extends ConsumerStatefulWidget {
  const SharedVaultScreen({super.key});

  @override
  ConsumerState<SharedVaultScreen> createState() => _SharedVaultScreenState();
}

class _SharedVaultScreenState extends ConsumerState<SharedVaultScreen> {
  @override
  Widget build(BuildContext context) {
    final isViewer = ref.watch(authProvider.select((state) => state.user?.isViewer == true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Vault'),
      ),
      body: const Center(
        child: Text(
          'No documents in Shared Vault',
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
