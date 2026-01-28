import 'package:flutter/material.dart';
import 'package:familysphere_app/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/family_setup_screen.dart';
import 'package:familysphere_app/features/home/presentation/screens/home_screen.dart';

/// Application Routes
/// 
/// Centralized route management for the app.
class AppRoutes {
  // Route names
  static const String login = '/login';
  static const String otpVerification = '/otp-verification';
  static const String profileSetup = '/profile-setup';
  static const String familySetup = '/family-setup';
  static const String home = '/home';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const PhoneLoginScreen());

      case otpVerification:
        final phoneNumber = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phoneNumber: phoneNumber),
        );

      case profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());

      case familySetup:
        return MaterialPageRoute(builder: (_) => const FamilySetupScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
