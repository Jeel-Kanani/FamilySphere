import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/network/api_client.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

class IntelligenceBriefing {
  final String id;
  final String title;
  final String description;
  final String priority;
  final String category;
  final String? actionLink;

  IntelligenceBriefing({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    this.actionLink,
  });

  factory IntelligenceBriefing.fromJson(Map<String, dynamic> json) {
    return IntelligenceBriefing(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      priority: json['priority'],
      category: json['category'],
      actionLink: json['actionLink'],
    );
  }
}

class IntelligenceState {
  final List<IntelligenceBriefing> briefings;
  final bool isLoading;
  final String? error;

  IntelligenceState({
    this.briefings = const [],
    this.isLoading = false,
    this.error,
  });

  IntelligenceState copyWith({
    List<IntelligenceBriefing>? briefings,
    bool? isLoading,
    String? error,
  }) {
    return IntelligenceState(
      briefings: briefings ?? this.briefings,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class IntelligenceNotifier extends StateNotifier<IntelligenceState> {
  final ApiClient _apiClient;
  final Ref _ref;

  IntelligenceNotifier(this._apiClient, this._ref) : super(IntelligenceState());

  Future<void> fetchBriefing() async {
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.get('/intelligence/briefing/$familyId');
      final List<dynamic> data = response.data;
      final briefings = data.map((json) => IntelligenceBriefing.fromJson(json)).toList();
      state = state.copyWith(briefings: briefings, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final intelligenceProvider = StateNotifierProvider<IntelligenceNotifier, IntelligenceState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return IntelligenceNotifier(apiClient, ref);
});
