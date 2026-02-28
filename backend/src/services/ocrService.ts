import Tesseract from 'tesseract.js';

/**
 * STRATEGY: 
 * We use a Hybrid Rule-Based + AI Intelligence Layer.
 * The system calculates a "Confidence Score" to determine if an event
 * should be auto-accepted or flagged for review.
 */

/**
 * Forensic visibility: tracks exactly how each field was extracted.
 * Critical for debugging edge cases without re-running OCR.
 */
export interface ExtractionTrace {
    method: 'regex' | 'keyword' | 'ai';
    matchedPattern: string;
    rawSnippet: string;
}

export interface OcrResult {
    rawText: string;
    docType: string;
    expiryDate?: Date;
    dueDate?: Date;
    amount?: number;
    confidence: number; // 0.0 to 1.0
    extractionTrace: {
        date?: ExtractionTrace;
        amount?: ExtractionTrace;
        docType?: ExtractionTrace;
    };
}

export const processDocumentOcr = async (fileUrl: string): Promise<OcrResult> => {
    try {
        // Step 1: Multi-language Text Extraction
        const { data: { text, confidence: ocrConfidence } } = await Tesseract.recognize(fileUrl, 'eng+hin');

        // Step 2: Hybrid Classification (Keyword + Pattern)
        const classification = classifyDocument(text);

        // Step 3: Metadata Extraction (with forensic traces)
        const dateResult = extractDates(text);
        const amountResult = extractAmount(text);

        // Step 4: Logic-Based Confidence Scoring
        let finalConfidence = ocrConfidence / 100;

        if (classification.score > 0.8) finalConfidence += 0.1;
        if (dateResult.dates.length > 2) finalConfidence -= 0.15;

        const now = new Date();
        const expiryDate = dateResult.dates.length > 0 ? dateResult.dates[0] : undefined;
        if (expiryDate && expiryDate < now) {
            finalConfidence -= 0.2;
        }

        return {
            rawText: text,
            docType: classification.type,
            expiryDate,
            dueDate: dateResult.dates.length > 1 ? dateResult.dates[1] : undefined,
            amount: amountResult.amount,
            confidence: Math.min(Math.max(finalConfidence, 0), 1),
            extractionTrace: {
                date: dateResult.trace,
                amount: amountResult.trace,
                docType: classification.trace
            }
        };
    } catch (error) {
        console.error('OCR Processing Failed:', error);
        return {
            rawText: '',
            docType: 'unknown',
            confidence: 0,
            extractionTrace: {}
        };
    }
};

const classifyDocument = (text: string): { type: string; score: number; trace: ExtractionTrace } => {
    const keywords: Record<string, string[]> = {
        'electricity_bill': ['electricity', 'mseb', 'power', 'bill', 'unit', 'consumer', 'kwh'],
        'insurance': ['policy', 'insurance', 'premium', 'sum insured', 'validity', 'nominee'],
        'passport': ['passport', 'republic of india', 'nationality', 'p-ind', 'visa'],
        'aadhaar': ['aadhaar', 'unique identification', 'government of india', 'male', 'female'],
        'driving_license': ['license', 'driving', 'transport', 'license no', 'haz', 'invalid'],
        'tax_return': ['income tax', 'itr', 'tax return', 'assessment year', 'pan card']
    };

    const lower = text.toLowerCase();
    let bestType = 'unknown';
    let bestScore = 0;
    let matchedKeywords: string[] = [];

    for (const [type, keys] of Object.entries(keywords)) {
        const matched = keys.filter(k => lower.includes(k));
        const score = matched.length / keys.length;
        if (score > bestScore) {
            bestScore = score;
            bestType = type;
            matchedKeywords = matched;
        }
    }

    // Build a raw snippet from the first match context
    const firstKeyword = matchedKeywords[0] || '';
    const idx = lower.indexOf(firstKeyword);
    const rawSnippet = idx >= 0 ? text.slice(Math.max(0, idx - 10), idx + 40).trim() : '';

    return {
        type: bestType,
        score: bestScore,
        trace: {
            method: 'keyword',
            matchedPattern: matchedKeywords.slice(0, 3).join(', ') || 'none',
            rawSnippet
        }
    };
};

const extractDates = (text: string): { dates: Date[]; trace?: ExtractionTrace } => {
    // Advanced Regex for common Indian/Global date formats
    const datePattern = /(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})|(\d{1,2})\s(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s(\d{2,4})/gi;
    const matches = text.match(datePattern) || [];

    if (matches.length === 0) return { dates: [] };

    // Prefer labels that indicate expiry/due context
    const expiryLabelPattern = /(expir[^\n:]{0,15}:|valid(?:ity)?\s*(?:till|upto|date)?[^\n:]{0,10}:|due\s*date[^\n:]{0,5}:|renew[^\n:]{0,10}:)/i;
    const labelMatch = text.match(expiryLabelPattern);
    const rawSnippet: string = labelMatch
        ? text.slice(text.indexOf(labelMatch[0]), text.indexOf(labelMatch[0]) + 60).trim()
        : matches[0] ?? '';

    const dates = matches.map(m => {
        if (/[a-zA-Z]/.test(m)) return new Date(m);

        const parts = m.split(/[\/\-\.]/);
        let day = parseInt(parts[0]);
        let month = parseInt(parts[1]);
        let year = parseInt(parts[2]);

        if (year < 100) year += 2000;
        if (month > 12 && day <= 12) { [day, month] = [month, day]; }

        return new Date(year, month - 1, day);
    }).filter(d => !isNaN(d.getTime()));

    return {
        dates,
        trace: {
            method: 'regex',
            matchedPattern: labelMatch ? labelMatch[0].trim() : datePattern.source.slice(0, 40),
            rawSnippet
        }
    };
};

const extractAmount = (text: string): { amount?: number; trace?: ExtractionTrace } => {
    const amountRegex = /(?:rs\.?|inr|total|₹|net payable|amount due)\s?(\d+(?:,\d+)*(?:\.\d{2})?)/i;
    const match = text.match(amountRegex);
    if (match) {
        return {
            amount: parseFloat(match[1].replace(/,/g, '')),
            trace: {
                method: 'regex',
                matchedPattern: match[0].split(/\d/)[0].trim(), // label before digit
                rawSnippet: match[0].trim()
            }
        };
    }
    return { amount: undefined };
};
