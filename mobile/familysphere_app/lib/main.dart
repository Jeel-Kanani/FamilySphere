import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/features/auth/presentation/screens/auth_checker.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local cache (if needed for documents, etc.)
  await Hive.initFlutter();
  
  // Initialize notification service for system notifications
  await NotificationService().initialize();
  
  // Clean up any leftover temp files from interrupted Lab operations
  LabFileManager().cleanupAllTemp();
  
  runApp(
    // Wrap app with ProviderScope for Riverpod
    const ProviderScope(
      child: FamilySphereApp(),
    ),
  );
}

class FamilySphereApp extends ConsumerWidget {
  const FamilySphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme mode for animated theme switching
    final themeMode = ref.watch(themeModeProvider);
    
    return AnimatedTheme(
      // Animated theme data that smoothly transitions between light/dark
      data: themeMode == ThemeMode.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      duration: AppTheme.normalAnimation,
      curve: Curves.easeInOut,
      child: MaterialApp(
        title: 'FamilySphere',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        onGenerateRoute: AppRoutes.generateRoute,
        home: const AuthChecker(),
      ),
    );
  }
}
