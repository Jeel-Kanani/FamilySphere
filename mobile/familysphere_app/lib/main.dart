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
    print('AuthChecker: initState called');
    // Check auth status on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('AuthChecker: Triggering checkAuthStatus');
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

    print('AuthChecker: Determined targetRoute = $targetRoute');
    if (mounted) {
      print('AuthChecker: Executing pushReplacementNamed($targetRoute)');
      Navigator.of(context).pushReplacementNamed(targetRoute);
    } else {
      print('AuthChecker: Not mounted, skipping navigation');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildCurrentScreen(authState),
    );
  }

  Widget _buildCurrentScreen(AuthState authState) {
    // If loading, show splash
    if (authState.isLoading) {
      return const SplashScreen(key: ValueKey('splash'));
    }

    // If authenticated, determine setup step
    if (authState.status == AuthStatus.authenticated) {
      final user = authState.user;
      
      if (user == null) {
        return const LoginScreen(key: ValueKey('login'));
      }
      
      if (!user.hasCompletedProfile) {
        return const ProfileSetupScreen(key: ValueKey('profile-setup'));
      }
      
      if (!user.hasFamily) {
        return const FamilySetupScreen(key: ValueKey('family-setup'));
      }
      
      return const HomeScreen(key: ValueKey('home'));
    }

    // Default to login
    return const LoginScreen(key: ValueKey('login'));
  }
}

/// Splash Screen - Shown while checking auth or navigating
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
              AppTheme.secondaryColor.withOpacity(0.9),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Icon or pulsing effect could go here
              const Icon(
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
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Family, Connected',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
