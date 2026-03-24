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
import 'package:familysphere_app/features/documents/presentation/screens/document_capture_screen.dart';
import 'package:familysphere_app/features/documents/domain/entities/document_entity.dart';
import 'package:familysphere_app/features/lab/presentation/screens/lab_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/merge_pdf_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/image_to_pdf_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/split_pdf_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/image_resize_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/protect_pdf_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/unlock_pdf_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/crop_image_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/compress_pdf_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/rotate_pdf_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/pdf_to_text_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/image_compress_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/image_convert_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/bg_remover_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/file_converter_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/zip_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/batch_rename_screen.dart';
import 'package:familysphere_app/features/lab/presentation/screens/preview_share_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/auth_checker.dart';
import 'package:familysphere_app/features/family/presentation/screens/join_family_screen.dart';
import 'package:familysphere_app/features/family/presentation/screens/join_success_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:familysphere_app/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:familysphere_app/features/documents/presentation/screens/admin_engine_dashboard.dart';
import 'package:familysphere_app/features/documents/presentation/screens/recent_documents_screen.dart';
import 'package:familysphere_app/features/intelligence/presentation/screens/intelligence_hub_screen.dart';
import 'package:familysphere_app/features/hub/presentation/screens/family_hub_screen.dart';
import 'package:familysphere_app/features/hub/presentation/screens/family_feed_screen.dart';
import 'package:familysphere_app/features/hub/presentation/screens/add_post_screen.dart';
import 'package:familysphere_app/features/chat/presentation/screens/family_chat_screen.dart';

/// Application Routes
///
/// Centralized route management for the app.
class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profileSetup = '/profile-setup';
  static const String profile = '/profile';
  static const String familySetup = '/family-setup';
  static const String joinFamily = '/join-family';
  static const String joinSuccess = '/join-success';
  static const String home = '/home';
  static const String familyDetails = '/family-details';
  static const String inviteMember = '/invite-member';
  static const String documents = '/documents';
  static const String addDocument = '/add-document';
  static const String documentViewer = '/document-viewer';
  static const String phoneLogin = '/phone-login';
  static const String otpVerification = '/otp-verification';
  static const String recentDocuments = '/recent-documents';
  static const String scanner = '/scanner';
  static const String documentCapture = '/document-capture';
  static const String lab = '/lab';
  static const String mergePdf = '/merge-pdf';
  static const String imageProcess = '/image-process';
  static const String splitPdf = '/split-pdf';
  static const String imageResize = '/image-resize';
  static const String protectPdf = '/protect-pdf';
  static const String unlockPdf = '/unlock-pdf';
  static const String cropImage = '/crop-image';
  static const String folderDetails = '/folder-details';
  static const String memberDocs = '/member-docs';
  static const String privateLocker = '/private-locker';
  static const String compressPdf = '/compress-pdf';
  static const String rotatePdf = '/rotate-pdf';
  static const String pdfToText = '/pdf-to-text';
  static const String imageCompress = '/image-compress';
  static const String imageConvert = '/image-convert';
  static const String bgRemover = '/bg-remover';
  static const String fileConverter = '/file-converter';
  static const String zipUnzip = '/zip-unzip';
  static const String batchRename = '/batch-rename';
  static const String previewShare = '/preview-share';
  static const String adminEngineDashboard = '/admin/engine-dashboard';
  static const String intelligence = '/intelligence';
  static const String hub = '/hub';
  static const String feed = '/feed';
  static const String addPost = '/add-post';
  static const String chat = '/chat';

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
        return MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(phoneNumber: phone));

      case profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case familySetup:
        return MaterialPageRoute(builder: (_) => const FamilySetupScreen());

      case joinFamily:
        return MaterialPageRoute(builder: (_) => const JoinFamilyScreen());

      case joinSuccess:
        return MaterialPageRoute(builder: (_) => const JoinSuccessScreen());

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
      
      case recentDocuments:
        return MaterialPageRoute(
          builder: (_) => const RecentDocumentsScreen(),
        );

      case addDocument:
        final args = settings.arguments;
        List<String>? paths;
        String? category;
        String? folder;
        String? memberId;

        if (args is List<String>) {
          paths = args;
        } else if (args is Map) {
          paths = args['paths'] as List<String>?;
          category = args['category'] as String?;
          folder = args['folder'] as String?;
          memberId = args['memberId'] as String?;
        }

        return MaterialPageRoute(
          builder: (_) => AddDocumentScreen(
            initialImagePaths: paths,
            initialCategory: category,
            initialFolder: folder,
            initialMemberId: memberId,
          ),
        );

      case documentViewer:
        final document = settings.arguments as DocumentEntity;
        return MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(document: document));

      case scanner:
      case documentCapture:
        final args = settings.arguments;
        bool returnOnly = false;
        String? category;
        String? folder;
        String? memberId;

        if (args is Map) {
          returnOnly = args['returnOnly'] as bool? ?? false;
          category = args['category'] as String?;
          folder = args['folder'] as String?;
          memberId = args['memberId'] as String?;
        }
        return MaterialPageRoute(
          builder: (_) => DocumentCaptureScreen(
            returnOnly: returnOnly,
            initialCategory: category,
            initialFolder: folder,
            initialMemberId: memberId,
          ),
        );

      case lab:
        return MaterialPageRoute(builder: (_) => const LabScreen());

      case mergePdf:
        return MaterialPageRoute(builder: (_) => const MergePdfScreen());

      case imageProcess:
        return MaterialPageRoute(builder: (_) => const ImageToPdfScreen());

      case splitPdf:
        return MaterialPageRoute(
          builder: (_) => const SplitPdfScreen(),
          settings: settings,
        );

      case imageResize:
        return MaterialPageRoute(
          builder: (_) => const ImageResizeScreen(),
          settings: settings,
        );

      case protectPdf:
        return MaterialPageRoute(
          builder: (_) => const ProtectPdfScreen(),
          settings: settings,
        );

      case unlockPdf:
        return MaterialPageRoute(
          builder: (_) => const UnlockPdfScreen(),
          settings: settings,
        );

      case cropImage:
        return MaterialPageRoute(
          builder: (_) => const CropImageScreen(),
          settings: settings,
        );

      case compressPdf:
        return MaterialPageRoute(
          builder: (_) => const CompressPdfScreen(),
          settings: settings,
        );

      case rotatePdf:
        return MaterialPageRoute(builder: (_) => const RotatePdfScreen());

      case pdfToText:
        return MaterialPageRoute(builder: (_) => const PdfToTextScreen());

      case imageCompress:
        return MaterialPageRoute(builder: (_) => const ImageCompressScreen());

      case imageConvert:
        return MaterialPageRoute(builder: (_) => const ImageConvertScreen());

      case bgRemover:
        return MaterialPageRoute(builder: (_) => const BgRemoverScreen());

      case fileConverter:
        return MaterialPageRoute(builder: (_) => const FileConverterScreen());

      case zipUnzip:
        return MaterialPageRoute(builder: (_) => const ZipScreen());

      case batchRename:
        return MaterialPageRoute(builder: (_) => const BatchRenameScreen());

      case previewShare:
        return MaterialPageRoute(builder: (_) => const PreviewShareScreen());

      case adminEngineDashboard:
        return MaterialPageRoute(builder: (_) => const AdminEngineDashboard());

      case intelligence:
        return MaterialPageRoute(builder: (_) => const IntelligenceHubScreen());

      case hub:
        return MaterialPageRoute(builder: (_) => const FamilyHubScreen());

      case feed:
        return MaterialPageRoute(builder: (_) => const FamilyFeedScreen());

      case addPost:
        return MaterialPageRoute(builder: (_) => const AddPostScreen());

      case chat:
        return MaterialPageRoute(builder: (_) => const FamilyChatScreen());

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
