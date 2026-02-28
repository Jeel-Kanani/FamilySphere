import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/models/ocr_status_result.dart';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────────

class OcrPollingState {
  final bool isPolling;
  final OcrStatusResult? result;
  final String? error;
  final int pollCount;

  const OcrPollingState({
    this.isPolling = false,
    this.result,
    this.error,
    this.pollCount = 0,
  });

  OcrPollingState copyWith({
    bool? isPolling,
    OcrStatusResult? result,
    String? error,
    int? pollCount,
  }) {
    return OcrPollingState(
      isPolling:  isPolling  ?? this.isPolling,
      result:     result     ?? this.result,
      error:      error,
      pollCount:  pollCount  ?? this.pollCount,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class OcrStatusNotifier extends StateNotifier<OcrPollingState> {
  final ApiClient _api;
  final String _docId;
  Timer? _timer;

  /// Max number of polls before giving up (30 × 3 s = 90 s).
  static const int _maxPolls = 30;
  static const Duration _interval = Duration(seconds: 3);

  OcrStatusNotifier(this._api, this._docId) : super(const OcrPollingState());

  /// Called automatically when the provider is first read.
  void startPolling() {
    if (state.isPolling) return;
    state = state.copyWith(isPolling: true);
    _poll(); // immediate first check
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;

    if (state.pollCount >= _maxPolls) {
      _stopPolling();
      state = state.copyWith(
        isPolling: false,
        error: 'Analysis timed out after 90 seconds',
      );
      return;
    }

    try {
      final response = await _api.get('/api/documents/$_docId/ocr-status');
      if (!mounted) return;

      final result = OcrStatusResult.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      state = state.copyWith(
        result:    result,
        pollCount: state.pollCount + 1,
        isPolling: !result.isFinished,
      );

      if (result.isFinished) _stopPolling();
    } catch (e) {
      if (!mounted) return;
      _stopPolling();
      state = state.copyWith(
        isPolling: false,
        error: 'Status check failed: $e',
      );
    }
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

// ── Provider (family — one per uploaded document) ─────────────────────────────

/// Usage:
///   ref.watch(ocrStatusProvider('documentId'))
///
/// Auto-starts polling immediately. Auto-disposes when no longer watched.
final ocrStatusProvider = StateNotifierProvider.autoDispose
    .family<OcrStatusNotifier, OcrPollingState, String>((ref, docId) {
  final api = ref.read(apiClientProvider);
  return OcrStatusNotifier(api, docId)..startPolling();
});
