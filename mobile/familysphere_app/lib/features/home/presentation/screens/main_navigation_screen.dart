import 'package:flutter/material.dart';
import 'package:familysphere_app/features/home/presentation/screens/home_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/vault_screen.dart';
import 'package:familysphere_app/features/chat/presentation/screens/hub_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/lab_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const VaultScreen(),
    const LabScreen(),
    const HubScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primaryColor,
              unselectedItemColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shield_rounded),
                  activeIcon: Icon(Icons.shield_rounded),
                  label: 'Vault',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.science_rounded),
                  activeIcon: Icon(Icons.science_rounded),
                  label: 'Lab',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_rounded),
                  activeIcon: Icon(Icons.inbox_rounded),
                  label: 'Requests',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
