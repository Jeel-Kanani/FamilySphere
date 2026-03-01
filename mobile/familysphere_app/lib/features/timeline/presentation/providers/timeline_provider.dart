import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/features/timeline/domain/entities/timeline_event.dart';
import 'package:familysphere_app/features/timeline/data/repositories/timeline_repository.dart';

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier(ref.watch(timelineRepositoryProvider));
});

class TimelineState {
  final List<TimelineEvent> futureEvents;
  final List<TimelineEvent> pastEvents;
  final bool isLoading;
  final bool isLoadingMoreFuture;
  final bool isLoadingMorePast;

  const TimelineState({
    this.futureEvents = const [],
    this.pastEvents = const [],
    this.isLoading = false,
    this.isLoadingMoreFuture = false,
    this.isLoadingMorePast = false,
  });

  TimelineState copyWith({
    List<TimelineEvent>? futureEvents,
    List<TimelineEvent>? pastEvents,
    bool? isLoading,
    bool? isLoadingMoreFuture,
    bool? isLoadingMorePast,
  }) {
    return TimelineState(
      futureEvents: futureEvents ?? this.futureEvents,
      pastEvents: pastEvents ?? this.pastEvents,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMoreFuture: isLoadingMoreFuture ?? this.isLoadingMoreFuture,
      isLoadingMorePast: isLoadingMorePast ?? this.isLoadingMorePast,
    );
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  final TimelineRepository _repository;

  TimelineNotifier(this._repository) : super(const TimelineState()) {
    _fetchInitialEvents();
  }

  Future<void> _fetchInitialEvents() async {
    state = state.copyWith(isLoading: true);
    try {
      final future = await _repository.getFutureEvents();
      final past = await _repository.getPastEvents();
      
      state = state.copyWith(
        futureEvents: future,
        pastEvents: past,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('Error fetching initial timeline: $e');
    }
  }

  Future<void> fetchMoreFuture() async {
    if (state.isLoadingMoreFuture || state.futureEvents.isEmpty) return;
    
    state = state.copyWith(isLoadingMoreFuture: true);
    try {
      final lastEvent = state.futureEvents.last;
      final newEvents = await _repository.getFutureEvents(cursor: lastEvent.startDate);
      
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
      final newEvents = await _repository.getPastEvents(cursor: lastEvent.startDate);
      
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

  /// Manually add an event (optimistic update)
  void addEvent(TimelineEvent event) {
    if (event.isFuture) {
      final newList = [...state.futureEvents, event];
      newList.sort((a, b) => a.startDate.compareTo(b.startDate));
      state = state.copyWith(futureEvents: newList);
    } else {
      final newList = [...state.pastEvents, event];
      newList.sort((a, b) => b.startDate.compareTo(a.startDate));
      state = state.copyWith(pastEvents: newList);
    }
  }

  /// Dismiss a review flag locally and on server
  Future<void> dismissReview(String eventId, {DateTime? correctedDate}) async {
    try {
      final updatedEvent = await _repository.dismissReview(eventId, correctedDate: correctedDate);
      _updateLocalEvent(updatedEvent);
    } catch (e) {
      debugPrint('Error dismissing review: $e');
    }
  }

  /// Update an event (locks from OCR overrides)
  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      final updatedEvent = await _repository.updateEvent(eventId, updates);
      _updateLocalEvent(updatedEvent);
    } catch (e) {
      debugPrint('Error updating event: $e');
    }
  }

  /// Create a new manual event on the server and add it locally
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
      futureEvents: state.futureEvents.map((e) => e.id == updatedEvent.id ? updatedEvent : e).toList(),
      pastEvents: state.pastEvents.map((e) => e.id == updatedEvent.id ? updatedEvent : e).toList(),
    );
  }
}
