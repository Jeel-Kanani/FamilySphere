import 'package:flutter/material.dart';
import 'package:familysphere_app/features/auth/presentation/screens/login_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/register_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/family_setup_screen.dart';
import 'package:familysphere_app/features/family/presentation/screens/family_details_screen.dart';
import 'package:familysphere_app/features/family/presentation/screens/invite_member_screen.dart';
import 'package:familysphere_app/features/home/presentation/screens/home_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_list_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/add_document_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/auth_checker.dart';

/// Application Routes
/// 
/// Centralized route management for the app.
class AppRoutes {
  // Route names
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profileSetup = '/profile-setup';
  static const String familySetup = '/family-setup';
  static const String home = '/home';
  static const String familyDetails = '/family-details';
  static const String inviteMember = '/invite-member';
  static const String documents = '/documents';
  static const String addDocument = '/add-document';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
        return MaterialPageRoute(builder: (_) => const AuthChecker());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());


      case profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());

      case familySetup:
        return MaterialPageRoute(builder: (_) => const FamilySetupScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case familyDetails:
        return MaterialPageRoute(builder: (_) => const FamilyDetailsScreen());

      case inviteMember:
        return MaterialPageRoute(builder: (_) => const InviteMemberScreen());

      case documents:
        return MaterialPageRoute(builder: (_) => const DocumentListScreen());

      case addDocument:
        return MaterialPageRoute(builder: (_) => const AddDocumentScreen());

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
