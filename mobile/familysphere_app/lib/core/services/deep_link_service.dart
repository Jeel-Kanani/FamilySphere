import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/family/presentation/providers/family_provider.dart';

final deepLinkServiceProvider = Provider((ref) => DeepLinkService(ref));

class DeepLinkService {
  final Ref _ref;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  DeepLinkService(this._ref);

  Future<void> initialize() async {
    // Check for initial link when app is opened from terminated state
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    // Listen for incoming links when app is in background/foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep Link Error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Handling Deep Link: $uri');
    
    // Check if it's a join link: familysphere://join?token=XYZ
    if (uri.scheme == 'familysphere' && uri.host == 'join') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _processJoinInvite(token);
      }
    }
  }

  Future<void> _processJoinInvite(String token) async {
    // Wait for navigator to be ready if needed
    await Future.delayed(const Duration(milliseconds: 500));
    
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      // Show loading or navigate to join screen with token
      // For now, let's try to join directly or show the join screen
      _ref.read(familyProvider.notifier).joinWithInvite(token: token);
      
      // Navigate to success or home
      Navigator.pushNamedAndRemoveUntil(context, '/join-success', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join via link: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
