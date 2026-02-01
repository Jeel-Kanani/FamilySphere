import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class SafeScreen extends StatelessWidget {
  const SafeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Safety & Finance'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expenses'),
              Tab(text: 'Family Map'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Shared Expenses & Budget')),
            Center(child: Text('Live Location & Family Map')),
          ],
        ),
      ),
    );
  }
}
