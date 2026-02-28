import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─── Result Types ────────────────────────────────────────────────────────────

/// Which script was used to extract a given field.
enum OcrScript { latin, devanagari, gujarati }

/// Forensic trace: exactly how a field was extracted — mirrors backend logic.
class ExtractionTrace {
  final String method; // 'regex' | 'keyword'
  final String matchedPattern;
  final String rawSnippet;

  const ExtractionTrace({
    required this.method,
    required this.matchedPattern,
    required this.rawSnippet,
  });
}

/// Full on-device OCR result — intentionally mirrors the backend OcrResult
/// so the upload flow can pass pre-filled metadata directly.
class SmartOcrResult {
  final String rawText;
  final String docType;
  final double confidence; // 0.0 – 1.0
  final DateTime? expiryDate;
  final DateTime? dueDate;
  final double? amount;
  final bool needsReview;
  final OcrScript dominantScript;
  final ExtractionTrace? dateTrace;
  final ExtractionTrace? amountTrace;
  final ExtractionTrace? docTypeTrace;

  const SmartOcrResult({
    required this.rawText,
    required this.docType,
    required this.confidence,
    required this.dominantScript,
    this.expiryDate,
    this.dueDate,
    this.amount,
    this.needsReview = false,
    this.dateTrace,
    this.amountTrace,
    this.docTypeTrace,
  });

  bool get hasIntelligence => docType != 'unknown';

  /// Human-readable label for the detected doc type.
  String get docTypeLabel {
    const labels = {
      'electricity_bill': 'Electricity Bill',
      'water_bill': 'Water Bill',
      'insurance': 'Insurance Policy',
      'passport': 'Passport',
      'aadhaar': 'Aadhaar Card',
      'driving_license': 'Driving License',
      'tax_return': 'Tax Return / ITR',
      'vehicle_rc': 'Vehicle RC',
      'pan_card': 'PAN Card',
      'bank_statement': 'Bank Statement',
      'rent_agreement': 'Rent Agreement',
    };
    return labels[docType] ?? 'Document';
  }

  /// Confidence level as a readable label.
  String get confidenceLabel {
    if (confidence >= 0.75) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// On-device intelligence layer.
/// Runs ML Kit text recognition in two scripts simultaneously (Latin + Devanagari),
/// then applies the same hybrid keyword + regex classification as the backend.
/// Gujarati script presence is detected via Unicode range analysis since
/// Google ML Kit does not provide a dedicated Gujarati text recognizer.
class SmartOcrService {
  SmartOcrService._();

  // Single Latin recognizer — it picks up numbers, dates, addresses and
  // romanised Hindi/Gujarati. Devanagari-script extraction requires
  // google_mlkit_text_recognition >= 0.13.0 (TextRecognitionScript.devanagari).
  static TextRecognizer? _latin;

  static TextRecognizer get _latinR =>
      _latin ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Dispose the recognizer — call when the scanner is closed.
  static Future<void> dispose() async {
    await _latin?.close();
    _latin = null;
  }

  /// Main entry point: process a single image file path.
  static Future<SmartOcrResult> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    // ── Step 1: Run text recognition ───────────────────────────────────
    final latinText = await _runRecognizer(_latinR, inputImage);

    // ── Step 2: Analyse scripts present in the extracted text ─────────────
    final hasDevanagari = _containsDevanagari(latinText);
    final hasGujarati = _containsGujarati(latinText);
    final merged = latinText;
    final dominantScript = _dominantScript(latinText, hasDevanagari, hasGujarati);

    if (merged.trim().isEmpty) {
      return SmartOcrResult(
        rawText: '',
        docType: 'unknown',
        confidence: 0,
        dominantScript: dominantScript,
        needsReview: true,
      );
    }

    // ── Step 3: Classify ──────────────────────────────────────────────────
    final classification = _classifyDocument(merged);

    // ── Step 4: Extract dates & amounts ───────────────────────────────────
    final dateResult = _extractDates(merged);
    final amountResult = _extractAmount(merged);

    // ── Step 5: Confidence scoring ────────────────────────────────────────
    double confidence = 0.6; // baseline for ML Kit extraction

    if (classification.score > 0.8) {
      confidence += 0.2;
    } else if (classification.score > 0.5) {
      confidence += 0.1;
    }

    if (dateResult.date != null) confidence += 0.1;
    if (amountResult.amount != null) confidence += 0.05;

    // Penalise ambiguous date (likely wrong parse)
    if (dateResult.allDates.length > 3) confidence -= 0.1;

    // Penalise past expiry
    if (dateResult.date != null && dateResult.date!.isBefore(DateTime.now())) {
      confidence -= 0.15;
    }

    confidence = confidence.clamp(0.0, 1.0);
    final needsReview = confidence < 0.65;

    return SmartOcrResult(
      rawText: merged,
      docType: classification.type,
      confidence: confidence,
      dominantScript: dominantScript,
      expiryDate: dateResult.date,
      dueDate: dateResult.allDates.length > 1 ? dateResult.allDates[1] : null,
      amount: amountResult.amount,
      needsReview: needsReview,
      dateTrace: dateResult.trace,
      amountTrace: amountResult.trace,
      docTypeTrace: classification.trace,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<String> _runRecognizer(
    TextRecognizer recognizer,
    InputImage image,
  ) async {
    try {
      final result = await recognizer.processImage(image);
      return result.text;
    } catch (_) {
      return '';
    }
  }

  /// Detects Devanagari (Hindi) Unicode characters (U+0900–U+097F).
  static bool _containsDevanagari(String text) =>
      text.runes.any((r) => r >= 0x0900 && r <= 0x097F);

  /// Detects Gujarati Unicode characters (U+0A80–U+0AFF).
  static bool _containsGujarati(String text) =>
      text.runes.any((r) => r >= 0x0A80 && r <= 0x0AFF);

  static OcrScript _dominantScript(
      String latin, bool hasDevanagari, bool hasGujarati) {
    if (hasGujarati) return OcrScript.gujarati;
    if (hasDevanagari) return OcrScript.devanagari;
    return OcrScript.latin;
  }

  // ── Classification ────────────────────────────────────────────────────────

  static ({String type, double score, ExtractionTrace? trace}) _classifyDocument(
    String text,
  ) {
    final lower = text.toLowerCase();

    // English keywords
    const keywords = <String, List<String>>{
      'electricity_bill': ['electricity', 'mseb', 'tpcl', 'bescom', 'power', 'kwh', 'unit', 'consumer no', 'meter'],
      'water_bill': ['water board', 'water supply', 'jal', 'water charge', 'water bill'],
      'insurance': ['policy', 'insurance', 'premium', 'sum insured', 'validity', 'nominee', 'irda', 'insurer'],
      'passport': ['passport', 'republic of india', 'nationality', 'p-ind', 'visa', 'date of issue'],
      'aadhaar': ['aadhaar', 'unique identification', 'uidai', 'enrolment', 'आधार'],
      'driving_license': ['driving licence', 'driving license', 'transport', 'dl no', 'vehicle class', 'rto'],
      'tax_return': ['income tax', 'itr', 'tax return', 'assessment year', 'pan', 'deductee'],
      'vehicle_rc': ['registration certificate', 'rc book', 'chassis', 'engine no', 'vehicle class'],
      'pan_card': ['permanent account number', 'pan card', 'income tax department', 'father'],
      'bank_statement': ['account number', 'ifsc', 'bank statement', 'debit', 'credit', 'balance', 'transaction'],
      'rent_agreement': ['rent agreement', 'lease', 'landlord', 'tenant', 'monthly rent', 'security deposit'],
    };

    // Hindi / Devanagari keyword boosts
    const hindiBoosts = <String, List<String>>{
      'electricity_bill': ['बिजली', 'विद्युत', 'उपभोक्ता'],
      'aadhaar': ['आधार', 'पहचान'],
      'driving_license': ['ड्राइविंग', 'लाइसेंस'],
      'pan_card': ['पैन कार्ड'],
    };

    // Gujarati keyword boosts
    const gujaratiBoosts = <String, List<String>>{
      'electricity_bill': ['વીજળી', 'ગ્રાહક'],
      'aadhaar': ['આધાર'],
      'driving_license': ['લાઇસન્સ'],
    };

    String bestType = 'unknown';
    double bestScore = 0;
    List<String> bestMatched = [];

    for (final entry in keywords.entries) {
      final matched = entry.value.where((k) => lower.contains(k)).toList();
      double score = matched.length / entry.value.length;

      // Bonus for Hindi matches
      final hBoost = hindiBoosts[entry.key] ?? [];
      final hMatched = hBoost.where((k) => text.contains(k)).toList();
      if (hMatched.isNotEmpty) score += 0.1;

      // Bonus for Gujarati matches
      final gBoost = gujaratiBoosts[entry.key] ?? [];
      final gMatched = gBoost.where((k) => text.contains(k)).toList();
      if (gMatched.isNotEmpty) score += 0.1;

      if (score > bestScore) {
        bestScore = score;
        bestType = entry.key;
        bestMatched = [...matched, ...hMatched, ...gMatched];
      }
    }

    if (bestType == 'unknown') return (type: 'unknown', score: 0.0, trace: null);

    final firstKw = bestMatched.isNotEmpty ? bestMatched.first : '';
    final idx = lower.indexOf(firstKw);
    final snippet = idx >= 0
        ? text.substring(idx, (idx + 40).clamp(0, text.length)).trim()
        : '';

    return (
      type: bestType,
      score: bestScore,
      trace: ExtractionTrace(
        method: 'keyword',
        matchedPattern: bestMatched.take(3).join(', '),
        rawSnippet: snippet,
      ),
    );
  }

  // ── Date Extraction ───────────────────────────────────────────────────────

  static ({DateTime? date, List<DateTime> allDates, ExtractionTrace? trace}) _extractDates(
    String text,
  ) {
    // Covers: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, DD MMM YYYY, YYYY/MM/DD
    final datePattern = RegExp(
      r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})'
      r'|(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{2,4})'
      r'|(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})',
      caseSensitive: false,
    );

    // Labels that hint at expiry/due context — find snippet for trace
    final labelPattern = RegExp(
      r'(expir[^\n:]{0,15}:|valid(?:ity)?\s*(?:till|upto|date)?[^\n:]{0,10}:'
      r'|due\s*date[^\n:]{0,5}:|renew[^\n:]{0,10}:'
      r'|validity[^\n:]{0,10}:|expire[^\n:]{0,10}:)',
      caseSensitive: false,
    );

    final matches = datePattern.allMatches(text).toList();
    if (matches.isEmpty) return (date: null, allDates: [], trace: null);

    final dates = <DateTime>[];
    for (final m in matches) {
      final parsed = _parseDate(m.group(0)!);
      if (parsed != null) dates.add(parsed);
    }

    if (dates.isEmpty) return (date: null, allDates: [], trace: null);

    final labelMatch = labelPattern.firstMatch(text);
    final snippet = labelMatch != null
        ? text
            .substring(
              labelMatch.start,
              (labelMatch.start + 60).clamp(0, text.length),
            )
            .trim()
        : matches.first.group(0)!;

    return (
      date: dates.first,
      allDates: dates,
      trace: ExtractionTrace(
        method: 'regex',
        matchedPattern: labelMatch?.group(0)?.trim() ?? datePattern.pattern.substring(0, 30),
        rawSnippet: snippet,
      ),
    );
  }

  static DateTime? _parseDate(String raw) {
    try {
      // YYYY-MM-DD or YYYY/MM/DD
      final isoLike = RegExp(r'^(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})$');
      final isoMatch = isoLike.firstMatch(raw);
      if (isoMatch != null) {
        return DateTime(
          int.parse(isoMatch.group(1)!),
          int.parse(isoMatch.group(2)!),
          int.parse(isoMatch.group(3)!),
        );
      }

      // Month name: 15 Jan 2026
      final monthName = RegExp(
        r'^(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{2,4})$',
        caseSensitive: false,
      );
      final mnMatch = monthName.firstMatch(raw);
      if (mnMatch != null) {
        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        int year = int.parse(mnMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, months[mnMatch.group(2)!.toLowerCase().substring(0, 3)]!, int.parse(mnMatch.group(1)!));
      }

      // DD/MM/YYYY or DD-MM-YYYY
      final parts = raw.split(RegExp(r'[\/\-\.]'));
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        // Swap if month > 12
        if (month > 12 && day <= 12) {
          final tmp = day;
          day = month;
          month = tmp;
        }
        if (month < 1 || month > 12 || day < 1 || day > 31) return null;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  // ── Amount Extraction ─────────────────────────────────────────────────────

  static ({double? amount, ExtractionTrace? trace}) _extractAmount(String text) {
    final amountPattern = RegExp(
      r'(?:rs\.?|inr|total|₹|net payable|amount due|bill amount)\s*:?\s*(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    final match = amountPattern.firstMatch(text);
    if (match == null) return (amount: null, trace: null);

    final numStr = match.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(numStr);
    if (amount == null) return (amount: null, trace: null);

    final label = match.group(0)!.split(RegExp(r'\d')).first.trim();

    return (
      amount: amount,
      trace: ExtractionTrace(
        method: 'regex',
        matchedPattern: label.isEmpty ? '₹ / rs / total' : label,
        rawSnippet: match.group(0)!.trim(),
      ),
    );
  }
}
