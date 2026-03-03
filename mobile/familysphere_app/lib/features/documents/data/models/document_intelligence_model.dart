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

  final String? summary;
  final DocumentFlags? flags;
  final RiskAnalysis? riskAnalysis;

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
    this.summary,
    this.flags,
    this.riskAnalysis,
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
      summary:          json['summary']?.toString(),
      flags:            json['document_flags'] != null 
                          ? DocumentFlags.fromJson(json['document_flags'] as Map<String, dynamic>)
                          : null,
      riskAnalysis:     json['risk_analysis'] != null
                          ? RiskAnalysis.fromJson(json['risk_analysis'] as Map<String, dynamic>)
                          : null,
    );
  }
}

// ── Classification ────────────────────────────────────────────────────────────

class DocumentClassification {
  final String docType;
  final String category;
  final String? subcategory;
  final double confidence;
  final String reasoning;

  const DocumentClassification({
    required this.docType,
    required this.category,
    this.subcategory,
    required this.confidence,
    required this.reasoning,
  });

  factory DocumentClassification.fromJson(Map<String, dynamic> json) {
    return DocumentClassification(
      docType:     json['document_type']?.toString() ?? json['doc_type']?.toString() ?? 'Other',
      category:    json['category']?.toString()  ?? 'Other',
      subcategory: json['subcategory']?.toString(),
      confidence:  (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning:   json['reasoning']?.toString() ?? '',
    );
  }

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

  // Plural Arrays
  final List<EntityPerson> people;
  final List<EntityOrg> organizations;
  final List<EntityIdPair> idNumbers;
  final List<EntityLocation> locations;
  final FinancialDetail? financialDetails;
  final List<EntityDatePair> importantDates;

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
    this.people = const [],
    this.organizations = const [],
    this.idNumbers = const [],
    this.locations = const [],
    this.financialDetails,
    this.importantDates = const [],
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
      
      people: (json['people'] as List<dynamic>?)
          ?.map((e) => EntityPerson.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      organizations: (json['organizations'] as List<dynamic>?)
          ?.map((e) => EntityOrg.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      idNumbers: (json['id_numbers'] as List<dynamic>?)
          ?.map((e) => EntityIdPair.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      locations: (json['locations'] as List<dynamic>?)
          ?.map((e) => EntityLocation.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      financialDetails: json['financial_details'] != null
          ? FinancialDetail.fromJson(json['financial_details'] as Map<String, dynamic>)
          : null,
      importantDates: (json['important_dates'] as List<dynamic>?)
          ?.map((e) => EntityDatePair.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

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

// ── Sub-Entity Types ──────────────────────────────────────────────────────────

class EntityPerson {
  final String name;
  final String role;
  final double confidence;
  const EntityPerson({required this.name, required this.role, required this.confidence});
  factory EntityPerson.fromJson(Map<String, dynamic> j) => EntityPerson(
    name: j['name']?.toString() ?? '', role: j['role']?.toString() ?? '', confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0);
}

class EntityOrg {
  final String name;
  final String type;
  final double confidence;
  const EntityOrg({required this.name, required this.type, required this.confidence});
  factory EntityOrg.fromJson(Map<String, dynamic> j) => EntityOrg(
    name: j['name']?.toString() ?? '', type: j['type']?.toString() ?? '', confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0);
}

class EntityIdPair {
  final String value;
  final String type;
  final double confidence;
  const EntityIdPair({required this.value, required this.type, required this.confidence});
  factory EntityIdPair.fromJson(Map<String, dynamic> j) => EntityIdPair(
    value: j['value']?.toString() ?? '', type: j['type']?.toString() ?? '', confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0);
}

class EntityLocation {
  final String value;
  final double confidence;
  const EntityLocation({required this.value, required this.confidence});
  factory EntityLocation.fromJson(Map<String, dynamic> j) => EntityLocation(
    value: j['value']?.toString() ?? '', confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0);
}

class FinancialDetail {
  final List<EntityAmount> amounts;
  final List<EntityIdPair> accountNumbers;
  const FinancialDetail({this.amounts = const [], this.accountNumbers = const []});
  factory FinancialDetail.fromJson(Map<String, dynamic> j) => FinancialDetail(
    amounts: (j['amounts'] as List?)?.map((x) => EntityAmount.fromJson(x)).toList() ?? [],
    accountNumbers: (j['account_numbers'] as List?)?.map((x) => EntityIdPair.fromJson(x)).toList() ?? [],
  );
}

class EntityAmount {
  final double value;
  final String currency;
  final double confidence;
  const EntityAmount({required this.value, required this.currency, required this.confidence});
  factory EntityAmount.fromJson(Map<String, dynamic> j) => EntityAmount(
    value: (j['value'] as num?)?.toDouble() ?? 0.0, currency: j['currency']?.toString() ?? 'INR', confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0);
}

class EntityDatePair {
  final String label;
  final DateTime? value;
  final double confidence;
  const EntityDatePair({required this.label, this.value, required this.confidence});
  factory EntityDatePair.fromJson(Map<String, dynamic> j) => EntityDatePair(
    label: j['label']?.toString() ?? '', 
    value: DateTime.tryParse(j['value']?.toString() ?? ''), 
    confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0);
}

// ── Flags & Risks ─────────────────────────────────────────────────────────────

class DocumentFlags {
  final bool isIdentity;
  final bool isFinancial;
  final bool isLegal;
  final bool isMedical;
  final bool isEducational;
  final bool isBusiness;

  const DocumentFlags({
    required this.isIdentity,
    required this.isFinancial,
    required this.isLegal,
    required this.isMedical,
    required this.isEducational,
    required this.isBusiness,
  });

  factory DocumentFlags.fromJson(Map<String, dynamic> j) {
    return DocumentFlags(
      isIdentity:    j['is_identity_document'] as bool? ?? false,
      isFinancial:   j['is_financial_document'] as bool? ?? false,
      isLegal:       j['is_legal_document']     as bool? ?? false,
      isMedical:     j['is_medical_document']   as bool? ?? false,
      isEducational: j['is_educational_document'] as bool? ?? false,
      isBusiness:    j['is_business_document']  as bool? ?? false,
    );
  }
}

class RiskAnalysis {
  final bool? isExpired;
  final bool? expiresSoon;
  final List<String> missingFields;
  final String? riskLevel;

  const RiskAnalysis({this.isExpired, this.expiresSoon, required this.missingFields, this.riskLevel});

  factory RiskAnalysis.fromJson(Map<String, dynamic> j) {
    return RiskAnalysis(
      isExpired:     j['is_expired'] as bool?,
      expiresSoon:   j['expires_within_6_months'] as bool?,
      missingFields: (j['missing_critical_fields'] as List?)?.map((x) => x.toString()).toList() ?? [],
      riskLevel:     j['risk_level']?.toString(),
    );
  }
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
  final double confidence;

  const SuggestedEvent({
    required this.title,
    required this.date,
    required this.eventType,
    required this.reason,
    required this.accepted,
    required this.confidence,
  });

  factory SuggestedEvent.fromJson(Map<String, dynamic> json) {
    return SuggestedEvent(
      title:      json['title']?.toString() ?? '',
      date:       DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      eventType:  json['event_type']?.toString() ?? 'milestone',
      reason:     json['reason']?.toString() ?? '',
      accepted:   json['accepted'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
