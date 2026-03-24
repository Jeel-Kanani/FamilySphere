import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';

class SharedVaultScreen extends StatefulWidget {
  @override
  State<SharedVaultScreen> createState() => _SharedVaultScreenState();
}

class _SharedVaultScreenState extends State<SharedVaultScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isViewer = authState is Authenticated && authState.user.isViewer;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Shared Vault'),
          ),
          body: Center(
            child: Text(
              'No documents in Shared Vault',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          floatingActionButton: isViewer ? null : FloatingActionButton(
            onPressed: () {
              // TODO: Implement add document functionality
            },
            tooltip: 'Add document',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}