import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:familysphere_app/core/config/api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus {
  unknown,
  online,
  offline,
}

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  NetworkStatusNotifier() : super(NetworkStatus.unknown) {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isRefreshing = false;

  Future<void> _initialize() async {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityResults(results);
    });
    await refresh();
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final results = await _connectivity.checkConnectivity();
      await _handleConnectivityResults(results);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _handleConnectivityResults(
      List<ConnectivityResult> results) async {
    if (_isTransportUnavailable(results)) {
      state = NetworkStatus.offline;
      return;
    }

    final backendReachable = await _canReachBackend();
    state = backendReachable ? NetworkStatus.online : NetworkStatus.offline;
  }

  bool _isTransportUnavailable(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.every((result) => result == ConnectivityResult.none);
  }

  Future<bool> _canReachBackend() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/health');
      final request = await client.getUrl(uri).timeout(
            const Duration(seconds: 3),
          );
      final response = await request.close().timeout(
            const Duration(seconds: 3),
          );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final networkStatusProvider =
    StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  final notifier = NetworkStatusNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(networkStatusProvider) == NetworkStatus.online;
});
