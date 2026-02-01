import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Planner'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Calendar'),
              Tab(text: 'Tasks & Chores'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Shared Family Calendar')),
            Center(child: Text('Manage Tasks & Chores')),
          ],
        ),
      ),
    );
  }
}
