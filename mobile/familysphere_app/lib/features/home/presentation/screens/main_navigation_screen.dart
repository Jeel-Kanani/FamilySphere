import 'package:flutter/material.dart';
import 'package:familysphere_app/features/home/presentation/screens/home_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/vault_screen.dart';
import 'package:familysphere_app/features/chat/presentation/screens/hub_screen.dart';
import 'package:familysphere_app/features/calendar/presentation/screens/planner_screen.dart';
import 'package:familysphere_app/features/expenses/presentation/screens/safe_screen.dart';
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
    const HubScreen(),
    const PlannerScreen(),
    const SafeScreen(),
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
              showSelectedLabels: false,
              showUnselectedLabels: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_rounded),
                  activeIcon: Icon(Icons.grid_view_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder_copy_rounded),
                  activeIcon: Icon(Icons.folder_copy_rounded),
                  label: 'Vault',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.forum_rounded),
                  activeIcon: Icon(Icons.forum_rounded),
                  label: 'Hub',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_rounded),
                  activeIcon: Icon(Icons.calendar_today_rounded),
                  label: 'Planner',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  activeIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'Safe',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
