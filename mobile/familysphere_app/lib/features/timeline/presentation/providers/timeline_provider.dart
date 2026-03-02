import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/timeline/domain/entities/timeline_event.dart';
import 'package:familysphere_app/features/timeline/data/repositories/timeline_repository.dart';

// ── Filter enum ────────────────────────────────────────────────────────────────────
enum TimelineFilter {
  all,
  upcoming,
  expiry,
  bills,
  birthday,
  milestone,
  completed,
}

extension TimelineFilterLabel on TimelineFilter {
  String get label {
    switch (this) {
      case TimelineFilter.all:       return 'All';
      case TimelineFilter.upcoming:  return 'Upcoming';
      case TimelineFilter.expiry:    return 'Expiry';
      case TimelineFilter.bills:     return 'Bills';
      case TimelineFilter.birthday:  return 'Birthdays';
      case TimelineFilter.milestone: return 'Milestones';
      case TimelineFilter.completed: return 'Done';
    }
  }

  String get emoji {
    switch (this) {
      case TimelineFilter.all:       return '🗂';
      case TimelineFilter.upcoming:  return '⏰';
      case TimelineFilter.expiry:    return '⚠️';
      case TimelineFilter.bills:     return '💰';
      case TimelineFilter.birthday:  return '🎂';
      case TimelineFilter.milestone: return '🏆';
      case TimelineFilter.completed: return '✅';
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────────────────
final timelineProvider =
    StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier(ref.watch(timelineRepositoryProvider));
});

// ── State ──────────────────────────────────────────────────────────────────────────────
class TimelineState {
  final List<TimelineEvent> futureEvents;
  final List<TimelineEvent> pastEvents;
  final bool isLoading;
  final bool isLoadingMoreFuture;
  final bool isLoadingMorePast;
  final TimelineFilter activeFilter;
  final String? errorMessage;

  const TimelineState({
    this.futureEvents = const [],
    this.pastEvents = const [],
    this.isLoading = false,
    this.isLoadingMoreFuture = false,
    this.isLoadingMorePast = false,
    this.activeFilter = TimelineFilter.all,
    this.errorMessage,
  });

  TimelineState copyWith({
    List<TimelineEvent>? futureEvents,
    List<TimelineEvent>? pastEvents,
    bool? isLoading,
    bool? isLoadingMoreFuture,
    bool? isLoadingMorePast,
    TimelineFilter? activeFilter,
    String? errorMessage,
  }) {
    return TimelineState(
      futureEvents: futureEvents ?? this.futureEvents,
      pastEvents: pastEvents ?? this.pastEvents,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMoreFuture: isLoadingMoreFuture ?? this.isLoadingMoreFuture,
      isLoadingMorePast: isLoadingMorePast ?? this.isLoadingMorePast,
      activeFilter: activeFilter ?? this.activeFilter,
      errorMessage: errorMessage,
    );
  }

  // ── Filtered views ─────────────────────────────────────────────────────
  List<TimelineEvent> get filteredFuture => _applyFilter(futureEvents);
  List<TimelineEvent> get filteredPast   => _applyFilter(pastEvents);

  List<TimelineEvent> _applyFilter(List<TimelineEvent> events) {
    switch (activeFilter) {
      case TimelineFilter.all:
        return events;
      case TimelineFilter.upcoming:
        return events
            .where((e) => e.status == TimelineEventStatus.upcoming)
            .toList();
      case TimelineFilter.expiry:
        return events
            .where((e) => e.type == TimelineEventType.expiry)
            .toList();
      case TimelineFilter.bills:
        return events
            .where((e) =>
                e.type == TimelineEventType.billDue ||
                e.type == TimelineEventType.billPaid)
            .toList();
      case TimelineFilter.birthday:
        return events
            .where((e) => e.type == TimelineEventType.birthday)
            .toList();
      case TimelineFilter.milestone:
        return events
            .where((e) => e.type == TimelineEventType.custom)
            .toList();
      case TimelineFilter.completed:
        return events
            .where((e) => e.status == TimelineEventStatus.completed)
            .toList();
    }
  }

  int get totalCount => futureEvents.length + pastEvents.length;
}

// ── Notifier ──────────────────────────────────────────────────────────────────────────────
class TimelineNotifier extends StateNotifier<TimelineState> {
  final TimelineRepository _repository;

  TimelineNotifier(this._repository) : super(const TimelineState()) {
    _fetchInitialEvents();
  }

  Future<void> _fetchInitialEvents() async {
    state = state.copyWith(isLoading: true);
    try {
      final future = await _repository.getFutureEvents();
      final past   = await _repository.getPastEvents();
      state = state.copyWith(
        futureEvents: future,
        pastEvents: past,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      debugPrint('Error fetching initial timeline: $e');
    }
  }

  Future<void> refresh() => _fetchInitialEvents();

  void setFilter(TimelineFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> fetchMoreFuture() async {
    if (state.isLoadingMoreFuture || state.futureEvents.isEmpty) return;
    state = state.copyWith(isLoadingMoreFuture: true);
    try {
      final lastEvent = state.futureEvents.last;
      final newEvents =
          await _repository.getFutureEvents(cursor: lastEvent.startDate);
      if (newEvents.isNotEmpty) {
        state = state.copyWith(
          futureEvents: [...state.futureEvents, ...newEvents],
        );
      }
    } catch (e) {
      debugPrint('Error fetching more future events: $e');
    } finally {
      state = state.copyWith(isLoadingMoreFuture: false);
    }
  }

  Future<void> fetchMorePast() async {
    if (state.isLoadingMorePast || state.pastEvents.isEmpty) return;
    state = state.copyWith(isLoadingMorePast: true);
    try {
      final lastEvent = state.pastEvents.last;
      final newEvents =
          await _repository.getPastEvents(cursor: lastEvent.startDate);
      if (newEvents.isNotEmpty) {
        state = state.copyWith(
          pastEvents: [...state.pastEvents, ...newEvents],
        );
      }
    } catch (e) {
      debugPrint('Error fetching more past events: $e');
    } finally {
      state = state.copyWith(isLoadingMorePast: false);
    }
  }

  void addEvent(TimelineEvent event) {
    if (event.isFuture) {
      final newList = [...state.futureEvents, event]
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      state = state.copyWith(futureEvents: newList);
    } else {
      final newList = [...state.pastEvents, event]
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      state = state.copyWith(pastEvents: newList);
    }
  }

  Future<void> dismissReview(String eventId, {DateTime? correctedDate}) async {
    try {
      final updatedEvent =
          await _repository.dismissReview(eventId, correctedDate: correctedDate);
      _updateLocalEvent(updatedEvent);
    } catch (e) {
      debugPrint('Error dismissing review: $e');
    }
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      final updatedEvent = await _repository.updateEvent(eventId, updates);
      _updateLocalEvent(updatedEvent);
    } catch (e) {
      debugPrint('Error updating event: $e');
    }
  }

  Future<bool> editEvent(
    String eventId, {
    required String title,
    required String description,
    required DateTime startDate,
    required String type,
  }) async {
    try {
      final updated = await _repository.editEvent(
        eventId,
        title: title,
        description: description,
        startDate: startDate,
        type: type,
      );
      _updateLocalEvent(updated);
      return true;
    } catch (e) {
      debugPrint('Error editing event: $e');
      return false;
    }
  }

  /// Optimistic delete — remove locally first, revert on server failure
  Future<bool> deleteEvent(String eventId) async {
    final prevFuture = [...state.futureEvents];
    final prevPast   = [...state.pastEvents];
    state = state.copyWith(
      futureEvents: state.futureEvents.where((e) => e.id != eventId).toList(),
      pastEvents:   state.pastEvents.where((e) => e.id != eventId).toList(),
    );
    try {
      await _repository.deleteEvent(eventId);
      return true;
    } catch (e) {
      state = state.copyWith(futureEvents: prevFuture, pastEvents: prevPast);
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  Future<bool> createEvent({
    required String title,
    required String type,
    required DateTime startDate,
    String description = '',
  }) async {
    try {
      final newEvent = await _repository.createEvent(
        title: title,
        type: type,
        startDate: startDate,
        description: description,
      );
      addEvent(newEvent);
      return true;
    } catch (e) {
      debugPrint('Error creating event: $e');
      return false;
    }
  }

  void _updateLocalEvent(TimelineEvent updatedEvent) {
    state = state.copyWith(
      futureEvents: state.futureEvents
          .map((e) => e.id == updatedEvent.id ? updatedEvent : e)
          .toList(),
      pastEvents: state.pastEvents
          .map((e) => e.id == updatedEvent.id ? updatedEvent : e)
          .toList(),
    );
  }
}
