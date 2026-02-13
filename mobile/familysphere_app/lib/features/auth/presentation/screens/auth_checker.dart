import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/features/auth/domain/entities/auth_state.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/auth/presentation/screens/login_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/family_setup_screen.dart';
import 'package:familysphere_app/features/home/presentation/screens/main_navigation_screen.dart';

/// Auth Checker - Determines initial route based on auth status
class AuthChecker extends ConsumerStatefulWidget {
  const AuthChecker({super.key});

  @override
  ConsumerState<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends ConsumerState<AuthChecker> {
  late final Future<void> _authCheckFuture;

  @override
  void initState() {
    super.initState();
    // Trigger immediately so login screen does not flash before auto-login decision.
    _authCheckFuture = ref.read(authProvider.notifier).checkAuthStatus();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return FutureBuilder<void>(
      future: _authCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen(key: ValueKey('splash'));
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildCurrentScreen(authState),
        );
      },
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
      
      return const MainNavigationScreen(key: ValueKey('home'));
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
              AppTheme.primaryColor.withValues(alpha: 0.8),
              AppTheme.secondaryColor.withValues(alpha: 0.9),
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
                      color: Colors.white.withValues(alpha: 0.9),
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
