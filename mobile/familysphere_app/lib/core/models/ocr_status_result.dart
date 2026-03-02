/// Mirrors the shape returned by GET /api/documents/:id/ocr-status
class OcrStatusResult {
  final String ocrStatus; // 'pending' | 'processing' | 'done' | 'failed'
  final String? ocrJobId;
  final double? ocrConfidence;
  final String? docType;
  final DateTime? expiryDate;
  final DateTime? dueDate;
  final double? amount;

  const OcrStatusResult({
    required this.ocrStatus,
    this.ocrJobId,
    this.ocrConfidence,
    this.docType,
    this.expiryDate,
    this.dueDate,
    this.amount,
  });

  bool get isPending           => ocrStatus == 'pending';
  bool get isProcessing        => ocrStatus == 'processing';
  bool get isDone              => ocrStatus == 'done';
  bool get isFailed            => ocrStatus == 'failed';
  bool get isNeedsConfirmation => ocrStatus == 'needs_confirmation';
  bool get isFinished          => isDone || isFailed || isNeedsConfirmation;
  bool get isActive            => isPending || isProcessing;

  factory OcrStatusResult.fromJson(Map<String, dynamic> json) {
    return OcrStatusResult(
      ocrStatus:      (json['ocrStatus'] as String?) ?? 'pending',
      ocrJobId:       json['ocrJobId'] as String?,
      ocrConfidence:  (json['ocrConfidence'] as num?)?.toDouble(),
      docType:        json['docType'] as String?,
      expiryDate:     json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())
          : null,
      dueDate:        json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString())
          : null,
      amount:         (json['amount'] as num?)?.toDouble(),
    );
  }

  /// Human-readable label for the detected document type.
  String get docTypeLabel {
    if (docType == null || docType == 'unknown') return 'Document';
    return docType!
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Confidence as a 0–100 integer percentage.
  int get confidencePct => ((ocrConfidence ?? 0) * 100).round();
}
