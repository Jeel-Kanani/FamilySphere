import 'package:flutter/material.dart';
import 'package:familysphere_app/features/auth/presentation/screens/login_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/register_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/family_setup_screen.dart';
import 'package:familysphere_app/features/family/presentation/screens/family_details_screen.dart';
import 'package:familysphere_app/features/family/presentation/screens/invite_member_screen.dart';
import 'package:familysphere_app/features/home/presentation/screens/home_screen.dart';
import 'package:familysphere_app/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/document_list_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/add_document_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/auth_checker.dart';

import 'package:familysphere_app/features/scanner/presentation/screens/document_scanner_screen.dart';
import 'package:familysphere_app/features/scanner/presentation/screens/image_process_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/member_wise_documents_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/private_locker_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/folder_details_screen.dart';

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


      case profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());

      case familySetup:
        return MaterialPageRoute(builder: (_) => const FamilySetupScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());

      case familyDetails:
        return MaterialPageRoute(builder: (_) => const FamilyDetailsScreen());

      case inviteMember:
        return MaterialPageRoute(builder: (_) => const InviteMemberScreen());

      case documents:
        return MaterialPageRoute(builder: (_) => const DocumentListScreen());

      case addDocument:
        final paths = settings.arguments as List<String>?;
        return MaterialPageRoute(builder: (_) => AddDocumentScreen(initialImagePaths: paths));

      case scanner:
        return MaterialPageRoute(builder: (_) => const DocumentScannerScreen());

      case imageProcess:
        final paths = settings.arguments as List<String>;
        return MaterialPageRoute(builder: (_) => ImageProcessScreen(imagePaths: paths));

      case folderDetails:
        final name = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => FolderDetailsScreen(folderName: name));

      case memberDocs:
        return MaterialPageRoute(builder: (_) => const MemberWiseDocumentsScreen());

      case privateLocker:
        return MaterialPageRoute(builder: (_) => const PrivateLockerScreen());

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
