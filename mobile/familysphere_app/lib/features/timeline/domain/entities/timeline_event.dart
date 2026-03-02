import 'package:flutter/material.dart';

enum TimelineEventType {
  expiry,
  billDue,
  billPaid,
  birthday,
  uploaded,
  renewed,
  custom,
}

enum TimelineEventStatus {
  upcoming,
  completed,
  cancelled,
  expired,
}

class TimelineEvent {
  final String id;
  final TimelineEventType type;
  final String title;
  final String description;
  final DateTime startDate;
  final TimelineEventStatus status;
  final IconData icon;
  final Color accentColor;
  final String? relatedDocumentId;
  final bool needsReview;
  final bool isUserModified;
  final double confidence;
  final DateTime? reviewAutoExpiredAt;

  const TimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.startDate,
    this.status = TimelineEventStatus.upcoming,
    required this.icon,
    required this.accentColor,
    this.relatedDocumentId,
    this.needsReview = false,
    this.isUserModified = false,
    this.confidence = 1.0,
    this.reviewAutoExpiredAt,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = _mapType(typeStr);
    
    final snapshot = json['snapshot'] as Map<String, dynamic>?;
    
    return TimelineEvent(
      id: json['_id'] as String,
      type: type,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      status: _mapStatus(json['status'] as String? ?? 'upcoming'),
      icon: _getIconForType(type),
      accentColor: _getColorForType(type),
      relatedDocumentId: json['relatedDocumentId'] as String?,
      needsReview: json['needsReview'] as bool? ?? false,
      isUserModified: json['isUserModified'] as bool? ?? false,
      confidence: (snapshot?['confidence'] as num? ?? 1.0).toDouble(),
      reviewAutoExpiredAt: json['reviewAutoExpiredAt'] != null 
          ? DateTime.parse(json['reviewAutoExpiredAt'] as String) 
          : null,
    );
  }

  static TimelineEventType _mapType(String type) {
    switch (type) {
      case 'expiry': return TimelineEventType.expiry;
      case 'bill_due': return TimelineEventType.billDue;
      case 'bill_paid': return TimelineEventType.billPaid;
      case 'birthday': return TimelineEventType.birthday;
      case 'document_upload': return TimelineEventType.uploaded;
      case 'task': return TimelineEventType.custom;
      case 'milestone': return TimelineEventType.custom;
      default: return TimelineEventType.custom;
    }
  }

  static TimelineEventStatus _mapStatus(String status) {
    switch (status) {
      case 'upcoming':  return TimelineEventStatus.upcoming;
      case 'completed': return TimelineEventStatus.completed;
      case 'cancelled': return TimelineEventStatus.cancelled;
      case 'expired':   return TimelineEventStatus.expired;
      default:          return TimelineEventStatus.upcoming;
    }
  }

  static IconData _getIconForType(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.expiry: return Icons.timer_rounded;
      case TimelineEventType.billDue: return Icons.receipt_long_rounded;
      case TimelineEventType.billPaid: return Icons.check_circle_rounded;
      case TimelineEventType.birthday: return Icons.cake_rounded;
      case TimelineEventType.uploaded: return Icons.file_present_rounded;
      case TimelineEventType.renewed: return Icons.autorenew;
      case TimelineEventType.custom: return Icons.event_note_rounded;
    }
  }

  static Color _getColorForType(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.expiry: return Colors.orangeAccent;
      case TimelineEventType.billDue: return Colors.redAccent;
      case TimelineEventType.billPaid: return Colors.greenAccent;
      case TimelineEventType.birthday: return Colors.pinkAccent;
      case TimelineEventType.uploaded: return Colors.blueAccent;
      case TimelineEventType.renewed: return Colors.cyanAccent;
      case TimelineEventType.custom: return Colors.purpleAccent;
    }
  }

  bool get isPast => startDate.isBefore(DateTime.now());
  bool get isFuture => !isPast;
}
