import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/core/utils/routes.dart';
import 'package:familysphere_app/core/providers/network_status_provider.dart';
import 'package:familysphere_app/features/auth/presentation/screens/auth_checker.dart';
import 'package:familysphere_app/features/documents/presentation/providers/document_provider.dart';
import 'package:familysphere_app/features/lab/domain/services/lab_file_manager.dart';
import 'package:familysphere_app/core/services/notification_service.dart';
import 'package:familysphere_app/core/services/deep_link_service.dart';
import 'package:familysphere_app/features/family/data/datasources/family_local_datasource.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local cache
  await Hive.initFlutter();
  await FamilyLocalDataSource().init();

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

class FamilySphereApp extends ConsumerStatefulWidget {
  const FamilySphereApp({super.key});

  @override
  ConsumerState<FamilySphereApp> createState() => _FamilySphereAppState();
}

class _FamilySphereAppState extends ConsumerState<FamilySphereApp>
    with WidgetsBindingObserver {
  ProviderSubscription<NetworkStatus>? _networkStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _networkStatusSubscription = ref.listenManual<NetworkStatus>(
      networkStatusProvider,
      (previous, next) {
        if (next == NetworkStatus.online &&
            previous != NetworkStatus.online) {
          ref.read(documentProvider.notifier).syncPendingJobs();
        }
      },
    );
    ref.read(networkStatusProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkStatusSubscription?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(networkStatusProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize DeepLinkService once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deepLinkServiceProvider).initialize();
    });

    final themeMode = ref.watch(themeModeProvider);

    return AnimatedTheme(
      data: themeMode == ThemeMode.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      duration: AppTheme.normalAnimation,
      curve: Curves.easeInOut,
      child: MaterialApp(
        title: 'FamilySphere',
        debugShowCheckedModeBanner: false,
        navigatorKey: ref.read(deepLinkServiceProvider).navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        onGenerateRoute: AppRoutes.generateRoute,
        home: const AuthChecker(),
      ),
    );
  }
}
