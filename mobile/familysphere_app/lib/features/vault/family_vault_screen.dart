import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';

class FamilyVaultScreen extends StatefulWidget {
  @override
  State<FamilyVaultScreen> createState() => _FamilyVaultScreenState();
}

class _FamilyVaultScreenState extends State<FamilyVaultScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isViewer = authState is Authenticated && authState.user.isViewer;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Family Vault'),
          ),
          body: Center(
            child: Text(
              'No documents in Family Vault',
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