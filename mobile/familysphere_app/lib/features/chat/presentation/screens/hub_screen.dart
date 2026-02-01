import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Hub'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Feed'),
              Tab(text: 'Family Tree'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Group & Private Chat')),
            Center(child: Text('Family Social Feed')),
            Center(child: Text('Visualize Family Relationships')),
          ],
        ),
      ),
    );
  }
}
