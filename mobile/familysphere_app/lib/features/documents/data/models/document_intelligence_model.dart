/// Mirrors the backend DocumentIntelligence MongoDB document.
class DocumentIntelligenceModel {
  final String id;
  final String documentId;
  final DocumentClassification classification;
  final DocumentEntities entities;
  final List<String> tags;
  final DocumentImportance importance;
  final List<SuggestedEvent> suggestedEvents;
  final bool needsConfirmation;
  final String aiModel;
  final DateTime analyzedAt;

  const DocumentIntelligenceModel({
    required this.id,
    required this.documentId,
    required this.classification,
    required this.entities,
    required this.tags,
    required this.importance,
    required this.suggestedEvents,
    required this.needsConfirmation,
    required this.aiModel,
    required this.analyzedAt,
  });

  factory DocumentIntelligenceModel.fromJson(Map<String, dynamic> json) {
    return DocumentIntelligenceModel(
      id:               json['_id']?.toString() ?? '',
      documentId:       json['documentId']?.toString() ?? '',
      classification:   DocumentClassification.fromJson(
                          json['classification'] as Map<String, dynamic>? ?? {}),
      entities:         DocumentEntities.fromJson(
                          json['entities'] as Map<String, dynamic>? ?? {}),
      tags:             (json['tags'] as List<dynamic>?)
                          ?.map((t) => t.toString())
                          .toList() ?? [],
      importance:       DocumentImportance.fromJson(
                          json['importance'] as Map<String, dynamic>? ?? {}),
      suggestedEvents:  (json['suggested_events'] as List<dynamic>?)
                          ?.map((e) => SuggestedEvent.fromJson(e as Map<String, dynamic>))
                          .toList() ?? [],
      needsConfirmation: json['needs_confirmation'] as bool? ?? false,
      aiModel:          json['ai_model']?.toString() ?? 'gemini-1.5-flash',
      analyzedAt:       json['analyzed_at'] != null
                          ? DateTime.tryParse(json['analyzed_at'].toString()) ?? DateTime.now()
                          : DateTime.now(),
    );
  }
}

// ── Classification ────────────────────────────────────────────────────────────

class DocumentClassification {
  final String docType;
  final String category;
  final double confidence;
  final String reasoning;

  const DocumentClassification({
    required this.docType,
    required this.category,
    required this.confidence,
    required this.reasoning,
  });

  factory DocumentClassification.fromJson(Map<String, dynamic> json) {
    return DocumentClassification(
      docType:    json['doc_type']?.toString()  ?? 'Other',
      category:   json['category']?.toString()  ?? 'Other',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning:  json['reasoning']?.toString() ?? '',
    );
  }

  /// Returns 0–100 as an integer percentage
  int get confidencePercent => (confidence * 100).round();

  bool get isHighConfidence => confidence >= 0.70;
}

// ── Entities ──────────────────────────────────────────────────────────────────

class DocumentEntities {
  final String? personName;
  final String? idNumber;
  final String? issuedBy;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime? dueDate;
  final double? amount;
  final String? institution;
  final String? address;

  const DocumentEntities({
    this.personName,
    this.idNumber,
    this.issuedBy,
    this.issueDate,
    this.expiryDate,
    this.dueDate,
    this.amount,
    this.institution,
    this.address,
  });

  factory DocumentEntities.fromJson(Map<String, dynamic> json) {
    return DocumentEntities(
      personName:  json['person_name']?.toString(),
      idNumber:    json['id_number']?.toString(),
      issuedBy:    json['issued_by']?.toString(),
      issueDate:   _parseDate(json['issue_date']),
      expiryDate:  _parseDate(json['expiry_date']),
      dueDate:     _parseDate(json['due_date']),
      amount:      (json['amount'] as num?)?.toDouble(),
      institution: json['institution']?.toString(),
      address:     json['address']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Returns non-null key-value pairs for display
  Map<String, String> get displayPairs {
    final map = <String, String>{};
    if (personName  != null && personName!.isNotEmpty)  map['Person']      = personName!;
    if (idNumber    != null && idNumber!.isNotEmpty)    map['ID Number']   = idNumber!;
    if (issuedBy    != null && issuedBy!.isNotEmpty)    map['Issued By']   = issuedBy!;
    if (institution != null && institution!.isNotEmpty) map['Institution'] = institution!;
    if (issueDate   != null)  map['Issue Date']   = _fmt(issueDate!);
    if (expiryDate  != null)  map['Expiry Date']  = _fmt(expiryDate!);
    if (dueDate     != null)  map['Due Date']     = _fmt(dueDate!);
    if (amount      != null)  map['Amount']       = '₹${amount!.toStringAsFixed(2)}';
    if (address     != null && address!.isNotEmpty)     map['Address']     = address!;
    return map;
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ── Importance ────────────────────────────────────────────────────────────────

class DocumentImportance {
  final int score;
  final String criticality;
  final String lifecycleStage;
  final int? renewalWindowDays;

  const DocumentImportance({
    required this.score,
    required this.criticality,
    required this.lifecycleStage,
    this.renewalWindowDays,
  });

  factory DocumentImportance.fromJson(Map<String, dynamic> json) {
    return DocumentImportance(
      score:             (json['score'] as num?)?.toInt() ?? 5,
      criticality:       json['criticality']?.toString() ?? 'medium',
      lifecycleStage:    json['lifecycle_stage']?.toString() ?? 'active',
      renewalWindowDays: (json['renewal_window_days'] as num?)?.toInt(),
    );
  }
}

// ── Suggested Event ───────────────────────────────────────────────────────────

class SuggestedEvent {
  final String title;
  final DateTime date;
  final String eventType;
  final String reason;
  final bool accepted;

  const SuggestedEvent({
    required this.title,
    required this.date,
    required this.eventType,
    required this.reason,
    required this.accepted,
  });

  factory SuggestedEvent.fromJson(Map<String, dynamic> json) {
    return SuggestedEvent(
      title:     json['title']?.toString() ?? '',
      date:      DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      eventType: json['event_type']?.toString() ?? 'milestone',
      reason:    json['reason']?.toString() ?? '',
      accepted:  json['accepted'] as bool? ?? false,
    );
  }
}
