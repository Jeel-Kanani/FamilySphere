import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/auth/domain/entities/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Hive
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
    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show splash screen while checking
    if (authState.isLoading) {
      return const SplashScreen();
    }

    // Navigate based on auth status
    if (authState.status == AuthStatus.authenticated) {
      final user = authState.user;
      
      if (user == null) {
        return const SplashScreen();
      }
      
      // Check if profile is complete
      if (!user.hasCompletedProfile) {
        // Navigate to profile setup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
        });
        return const SplashScreen();
      }
      
      // Check if user has family
      if (!user.hasFamily) {
        // Navigate to family setup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, AppRoutes.familySetup);
        });
        return const SplashScreen();
      }
      
      // User is fully set up - go to home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
      return const SplashScreen();
    }

    // Not authenticated - go to login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
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
