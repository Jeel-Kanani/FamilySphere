import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/family_activity_entity.dart';
import '../../data/datasources/hub_remote_datasource.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:familysphere_app/core/services/socket_service.dart';

class HubState {
  final List<PostEntity> feed;
  final List<FamilyActivityEntity> activities;
  final bool isLoading;
  final String? error;

  HubState({
    this.feed = const [],
    this.activities = const [],
    this.isLoading = false,
    this.error,
  });

  HubState copyWith({
    List<PostEntity>? feed,
    List<FamilyActivityEntity>? activities,
    bool? isLoading,
    String? error,
  }) {
    return HubState(
      feed: feed ?? this.feed,
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}


class HubNotifier extends StateNotifier<HubState> {
  final HubRemoteDataSource _dataSource;
  final Ref _ref;

  HubNotifier(this._dataSource, this._ref) : super(HubState());

  void initSocketListeners() {
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    final socketService = _ref.read(socketServiceProvider);
    socketService.joinFamily(familyId);

    socketService.on('new_post', (data) {
      final newPost = PostEntity.fromJson(data);
      if (!state.feed.any((p) => p.id == newPost.id)) {
        state = state.copyWith(feed: [newPost, ...state.feed]);
      }
    });

    socketService.on('new_activity', (data) {
      final newActivity = FamilyActivityEntity.fromJson(data);
      if (!state.activities.any((a) => a.id == newActivity.id)) {
        state = state.copyWith(activities: [newActivity, ...state.activities]);
      }
    });
  }

  Future<void> loadHubData() async {
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final feed = await _dataSource.getFeed(familyId);
      final activities = await _dataSource.getActivities(familyId);
      state = state.copyWith(feed: feed, activities: activities, isLoading: false);
      
      // Ensure real-time listeners are active
      initSocketListeners();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createPost({
    required String content,
    List<String> mediaUrls = const [],
    required String type,
  }) async {
    final familyId = _ref.read(authProvider).user?.familyId;
    if (familyId == null) return;

    try {
      final post = await _dataSource.createPost(
        familyId: familyId,
        content: content,
        mediaUrls: mediaUrls,
        type: type,
      );
      if (!state.feed.any((p) => p.id == post.id)) {
        state = state.copyWith(feed: [post, ...state.feed]);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleLike(String postId) async {
    try {
      final updatedPost = await _dataSource.toggleLike(postId);
      state = state.copyWith(
        feed: state.feed.map((p) => p.id == postId ? updatedPost : p).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final hubProvider = StateNotifierProvider<HubNotifier, HubState>((ref) {
  final dataSource = ref.watch(hubRemoteDataSourceProvider);
  return HubNotifier(dataSource, ref);
});
