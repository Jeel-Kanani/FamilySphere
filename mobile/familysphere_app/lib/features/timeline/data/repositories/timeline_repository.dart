import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/timeline_event.dart';

final timelineRepositoryProvider = Provider((ref) {
  return TimelineRepository(ref.watch(apiClientProvider));
});

class TimelineRepository {
  final ApiClient _apiClient;

  TimelineRepository(this._apiClient);

  Future<List<TimelineEvent>> getFutureEvents({DateTime? cursor}) async {
    final response = await _apiClient.get(
      '/api/events/future',
      queryParameters: {
        if (cursor != null) 'cursor': cursor.toIso8601String(),
        'limit': 20,
      },
    );

    if (response.statusCode == 200) {
      final List data = response.data['data'];
      return data.map((json) => TimelineEvent.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch future events');
  }

  Future<List<TimelineEvent>> getPastEvents({DateTime? cursor}) async {
    final response = await _apiClient.get(
      '/api/events/past',
      queryParameters: {
        if (cursor != null) 'cursor': cursor.toIso8601String(),
        'limit': 20,
      },
    );

    if (response.statusCode == 200) {
      final List data = response.data['data'];
      return data.map((json) => TimelineEvent.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch past events');
  }

  Future<TimelineEvent> updateEvent(String id, Map<String, dynamic> updates) async {
    final response = await _apiClient.patch(
      '/api/events/$id',
      data: updates,
    );

    if (response.statusCode == 200) {
      return TimelineEvent.fromJson(response.data['data']);
    }
    throw Exception('Failed to update event');
  }

  Future<TimelineEvent> dismissReview(String id, {DateTime? correctedDate}) async {
    final response = await _apiClient.patch(
      '/api/events/$id/dismiss-review',
      data: {
        if (correctedDate != null) 'correctedDate': correctedDate.toIso8601String(),
      },
    );

    if (response.statusCode == 200) {
      return TimelineEvent.fromJson(response.data['data']);
    }
    throw Exception('Failed to dismiss review');
  }

  Future<TimelineEvent> createEvent({
    required String title,
    required String type,
    required DateTime startDate,
    String description = '',
  }) async {
    final response = await _apiClient.post(
      '/api/events',
      data: {
        'title': title,
        'type': type,
        'startDate': startDate.toIso8601String(),
        'description': description,
        'source': 'manual',
      },
    );

    if (response.statusCode == 201) {
      return TimelineEvent.fromJson(response.data['data']);
    }
    throw Exception('Failed to create event');
  }

  Future<void> deleteEvent(String id) async {
    final response = await _apiClient.delete('/api/events/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete event');
    }
  }

  Future<TimelineEvent> editEvent(
    String id, {
    required String title,
    required String description,
    required DateTime startDate,
    required String type,
  }) async {
    final response = await _apiClient.patch(
      '/api/events/$id',
      data: {
        'title': title,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'type': type,
        'isUserModified': true,
      },
    );
    if (response.statusCode == 200) {
      return TimelineEvent.fromJson(response.data['data']);
    }
    throw Exception('Failed to edit event');
  }
}
