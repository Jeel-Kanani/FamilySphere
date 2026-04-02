import 'dart:async';

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
import 'package:familysphere_app/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:familysphere_app/features/chat/presentation/providers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local cache
  await Hive.initFlutter();
  await FamilyLocalDataSource().init();
  await ChatLocalDataSource().init();

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
  ProviderSubscription<DocumentState>? _documentSubscription;
  ProviderSubscription<ChatState>? _chatSubscription;
  Timer? _autoSyncTimer;
  int _autoSyncDelaySeconds = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _networkStatusSubscription = ref.listenManual<NetworkStatus>(
      networkStatusProvider,
      (previous, next) {
        if (next == NetworkStatus.online &&
            previous != NetworkStatus.online) {
          _scheduleAutoSync(immediate: true);
        }
      },
    );
    _documentSubscription = ref.listenManual<DocumentState>(
      documentProvider,
      (_, next) {
        if (next.pendingSyncJobs > 0) {
          _scheduleAutoSync();
        }
      },
    );
    _chatSubscription = ref.listenManual<ChatState>(
      chatProvider,
      (_, next) {
        if (next.pendingQueueCount > 0) {
          _scheduleAutoSync();
        }
      },
    );
    ref.read(networkStatusProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkStatusSubscription?.close();
    _documentSubscription?.close();
    _chatSubscription?.close();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(networkStatusProvider.notifier).refresh();
      _scheduleAutoSync(immediate: true);
    }
  }

  void _scheduleAutoSync({bool immediate = false}) {
    if (ref.read(networkStatusProvider) != NetworkStatus.online) {
      return;
    }
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(
      Duration(seconds: immediate ? 1 : _autoSyncDelaySeconds),
      _runAutoSync,
    );
  }

  Future<void> _runAutoSync() async {
    if (!mounted) return;
    if (ref.read(networkStatusProvider) != NetworkStatus.online) return;

    final hasDocumentWork = ref.read(documentProvider).pendingSyncJobs > 0;
    final hasChatWork = ref.read(chatProvider).pendingQueueCount > 0;
    if (!hasDocumentWork && !hasChatWork) {
      _autoSyncDelaySeconds = 15;
      return;
    }

    if (hasDocumentWork) {
      await ref.read(documentProvider.notifier).syncPendingJobs();
    }
    if (hasChatWork) {
      await ref.read(chatProvider.notifier).syncPendingMessages();
    }

    final remainingDocumentWork = ref.read(documentProvider).pendingSyncJobs > 0;
    final remainingChatWork = ref.read(chatProvider).pendingQueueCount > 0;
    if (remainingDocumentWork || remainingChatWork) {
      _autoSyncDelaySeconds = (_autoSyncDelaySeconds * 2).clamp(15, 120);
      _scheduleAutoSync();
    } else {
      _autoSyncDelaySeconds = 15;
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
