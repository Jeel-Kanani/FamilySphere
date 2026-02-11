import 'package:flutter/material.dart';
import 'package:familysphere_app/features/auth/presentation/screens/login_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/register_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/family_setup_screen.dart';
import 'package:familysphere_app/features/family/presentation/screens/family_details_screen.dart';
import 'package:familysphere_app/features/family/presentation/screens/invite_member_screen.dart';
import 'package:familysphere_app/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_list_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/add_document_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_viewer_screen.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/auth/presentation/screens/auth_checker.dart';
import 'package:familysphere_app/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/otp_verification_screen.dart';

/// Application Routes
/// 
/// Centralized route management for the app.
class AppRoutes {
  // Route names
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profileSetup = '/profile-setup';
  static const String profile = '/profile';
  static const String familySetup = '/family-setup';
  static const String home = '/home';
  static const String familyDetails = '/family-details';
  static const String inviteMember = '/invite-member';
  static const String documents = '/documents';
  static const String addDocument = '/add-document';
  static const String documentViewer = '/document-viewer';
  static const String phoneLogin = '/phone-login';
  static const String otpVerification = '/otp-verification';
  static const String scanner = '/scanner';
  static const String imageProcess = '/image-process';
  static const String folderDetails = '/folder-details';
  static const String memberDocs = '/member-docs';
  static const String privateLocker = '/private-locker';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
        return MaterialPageRoute(builder: (_) => const AuthChecker());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case phoneLogin:
        return MaterialPageRoute(builder: (_) => const PhoneLoginScreen());

      case otpVerification:
        final phone = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => OtpVerificationScreen(phoneNumber: phone));

      case profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case familySetup:
        return MaterialPageRoute(builder: (_) => const FamilySetupScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());

      case familyDetails:
        return MaterialPageRoute(builder: (_) => const FamilyDetailsScreen());

      case inviteMember:
        return MaterialPageRoute(builder: (_) => const InviteMemberScreen());

      case documents:
        final args = settings.arguments;
        String? category;
        if (args is Map && args['category'] is String) {
          category = args['category'] as String;
        }
        return MaterialPageRoute(
          builder: (_) => DocumentListScreen(initialCategory: category),
        );

      case addDocument:
        final paths = settings.arguments as List<String>?;
        return MaterialPageRoute(builder: (_) => AddDocumentScreen(initialImagePaths: paths));

      case documentViewer:
        final document = settings.arguments as DocumentEntity;
        return MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: document));

      case scanner:
      case imageProcess:
      case folderDetails:
      case memberDocs:
      case privateLocker:
        // Placeholder for missing screens to allow compilation
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Coming Soon')),
            body: const Center(child: Text('This feature is coming soon!')),
          ),
        );

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
