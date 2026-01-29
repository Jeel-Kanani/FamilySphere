import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/auth/domain/entities/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local cache (if needed for documents, etc.)
  await Hive.initFlutter();
  
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
    return MaterialApp(
      title: 'FamilySphere',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRoutes.generateRoute,
      home: const AuthChecker(),
    );
  }
}

/// Auth Checker - Determines initial route based on auth status
class AuthChecker extends ConsumerStatefulWidget {
  const AuthChecker({super.key});

  @override
  ConsumerState<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends ConsumerState<AuthChecker> {
  @override
  void initState() {
    super.initState();
    // Check auth status on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  void _navigateBasedOnAuth(AuthState authState) {
    if (!mounted) return;
    
    String targetRoute;
    
    if (authState.status == AuthStatus.authenticated) {
      final user = authState.user;
      
      if (user == null) return;
      
      // Check if profile is complete
      if (!user.hasCompletedProfile) {
        targetRoute = AppRoutes.profileSetup;
      }
      // Check if user has family
      else if (!user.hasFamily) {
        targetRoute = AppRoutes.familySetup;
      }
      // User is fully set up - go to home
      else {
        targetRoute = AppRoutes.home;
      }
    } else if (!authState.isLoading) {
      // Not authenticated and not loading - go to login
      targetRoute = AppRoutes.login;
    } else {
      // Still loading, don't navigate yet
      return;
    }

    Navigator.of(context).pushReplacementNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    // Use listen instead of watch to avoid rebuilding
    ref.listen(authProvider, (previous, next) {
      // Only navigate when auth status changes from loading to loaded
      if (previous?.isLoading == true && !next.isLoading) {
        _navigateBasedOnAuth(next);
      }
    });

    return const SplashScreen();
  }
}

/// Splash Screen - Shown while checking auth or navigating
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'FamilySphere',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Family, Connected',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withAlpha((255 * 0.9).round()),
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
