import Tesseract from 'tesseract.js';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { ALLOWED_DOC_TYPES, DOC_CATEGORIES, ISuggestedEvent } from '../models/DocumentIntelligence';
import https from 'https';
import http from 'http';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ExtractionTrace {
    method: 'regex' | 'keyword' | 'ai';
    matchedPattern: string;
    rawSnippet: string;
}

/** Legacy fields kept on OcrResult so existing worker/controller code is unaffected */
export interface OcrResult {
    rawText: string;
    docType: string;
    expiryDate?: Date;
    dueDate?: Date;
    amount?: number;
    confidence: number;
    extractionTrace: {
        date?: ExtractionTrace;
        amount?: ExtractionTrace;
        docType?: ExtractionTrace;
    };
    // ── NEW: Smart intelligence payload (present when Gemini succeeds) ────────
    intelligence?: SmartIntelligence;
}

export interface SmartIntelligence {
    classification: {
        doc_type: string;
        category: string;
        confidence: number;
        reasoning: string;
    };
    entities: {
        person_name?: string;
        id_number?: string;
        issued_by?: string;
        issue_date?: Date;
        expiry_date?: Date;
        due_date?: Date;
        amount?: number;
        institution?: string;
        address?: string;
    };
    tags: string[];
    importance: {
        score: number;
        criticality: 'low' | 'medium' | 'high' | 'critical';
        lifecycle_stage: string;
        renewal_window_days?: number;
    };
    suggested_events: Omit<ISuggestedEvent, 'accepted'>[];
    ai_model: string;
    raw_ai_response: string;
}

//  Gemini client ───────────────────────────────────────────────────────────────

const getGeminiClient = () => {
    const key = process.env.GEMINI_API_KEY;
    if (!key || key === 'your_gemini_api_key_here') return null;
    return new GoogleGenerativeAI(key);
};

// ── Smart prompt ──────────────────────────────────────────────────────────────

const SMART_PROMPT = (text: string) => `You are a Smart Document Intelligence Engine for a family document management app.
Analyze the following extracted document text and return STRICT JSON only.
No markdown. No explanation. No code blocks. Just raw JSON.

ALLOWED document types (pick the closest match):
${ALLOWED_DOC_TYPES.join(', ')}

ALLOWED categories: ${DOC_CATEGORIES.join(', ')}

Return this exact JSON structure:
{
  "doc_type": "string from allowed types",
  "category": "string from allowed categories",
  "confidence": 0.0 to 1.0,
  "reasoning": "one line explaining why you chose this type",
  "entities": {
    "person_name": "string or null",
    "id_number": "string or null",
    "issued_by": "string or null",
    "issue_date": "YYYY-MM-DD or null",
    "expiry_date": "YYYY-MM-DD or null",
    "due_date": "YYYY-MM-DD or null",
    "amount": number or null,
    "institution": "string or null",
    "address": "string or null"
  },
  "tags": ["max 6 lowercase tags, no #, e.g. identity, travel, urgent, renewal-required, government, financial-risk"],
  "importance": {
    "score": 1 to 10,
    "criticality": "low or medium or high or critical",
    "lifecycle_stage": "e.g. active, expiring-soon, expired, pending, completed",
    "renewal_window_days": number or null
  },
  "suggested_events": [
    {
      "title": "short event title",
      "date": "YYYY-MM-DD",
      "event_type": "expiry or renewal or payment or follow_up or milestone",
      "reason": "why this event matters to the user"
    }
  ]
}

Rules for suggested_events:
- Only include events that genuinely matter to the user
- Do NOT add events without a concrete date
- Do NOT add duplicate events (e.g., only ONE expiry event per document)
- Passport/License/Insurance: add expiry + renewal reminder (renewal = expiry minus renewal_window_days)
- Bills: add payment due event only
- Loan: add EMI start, final payment if dates are present
- Medical reports: add follow-up only if explicitly mentioned in text
- Max 3 events per document

Document text (first 3500 chars):
${text.slice(0, 3500)}`;

// ── Download URL → Buffer ────────────────────────────────────────────────────
// Passing a URL directly to Tesseract.js in Node.js is unreliable — it can
// silently return empty text when the fetch times out or is blocked.
// We download to an in-memory Buffer first, then give Tesseract the raw bytes.
const downloadToBuffer = (url: string): Promise<Buffer> =>
    new Promise((resolve, reject) => {
        const client = url.startsWith('https') ? https : http;
        client.get(url, { timeout: 30000 }, (res) => {
            if (res.statusCode && res.statusCode >= 400) {
                reject(new Error(`Download failed: HTTP ${res.statusCode} for ${url.slice(0, 80)}`));
                return;
            }
            const chunks: Buffer[] = [];
            res.on('data', (chunk: Buffer) => chunks.push(chunk));
            res.on('end', () => resolve(Buffer.concat(chunks)));
            res.on('error', reject);
        }).on('error', reject).on('timeout', () => reject(new Error('Download timeout')));
    });

// ── PDF → JPEG URL transform (Cloudinary) ───────────────────────────────────
const transformUrlForOcr = (fileUrl: string): string => {
    const lower = fileUrl.toLowerCase();
    if (lower.includes('.pdf') && fileUrl.includes('/upload/')) {
        return fileUrl.replace('/upload/', '/upload/f_jpg,pg_1/');
    }
    return fileUrl;
};

//  Main entry point ────────────────────────────────────────────────────────────

export const processDocumentOcr = async (fileUrl: string): Promise<OcrResult> => {
    try {
        // Step 1: Resolve the URL — convert PDF to image if needed
        const ocrUrl = transformUrlForOcr(fileUrl);
        const isPdf = fileUrl.toLowerCase().includes('.pdf');
        console.log(`[OCR] Processing: ${isPdf ? `PDF→JPEG via Cloudinary` : 'image'} | ${ocrUrl.slice(0, 80)}…`);

        // Step 2: Download image to buffer — reliable on Render and local
        let imageBuffer: Buffer;
        try {
            imageBuffer = await downloadToBuffer(ocrUrl);
            console.log(`[OCR] Downloaded ${imageBuffer.length} bytes from Cloudinary`);
        } catch (dlErr: any) {
            throw new Error(`Failed to download image for OCR: ${dlErr.message}`);
        }

        // Step 3: Tesseract → pixel to raw text (eng+hin, fallback to eng)
        let text = '';
        let ocrConfidence = 0;
        try {
            const result = await Tesseract.recognize(imageBuffer, 'eng+hin');
            text = result.data.text;
            ocrConfidence = result.data.confidence;
        } catch (tessErr: any) {
            console.warn('[OCR] eng+hin failed, retrying with eng only:', tessErr.message);
            const fallbackResult = await Tesseract.recognize(imageBuffer, 'eng');
            text = fallbackResult.data.text;
            ocrConfidence = fallbackResult.data.confidence;
        }

        if (!text || text.trim().length < 10) {
            console.warn(`[OCR] Extracted 0/very few chars from ${ocrUrl.slice(0, 60)}… — Tesseract confidence: ${ocrConfidence}`);
            return { rawText: text || '', docType: 'unknown', confidence: 0, extractionTrace: {} };
        }

        console.log(`[OCR] Extracted ${text.trim().length} chars, Tesseract confidence: ${ocrConfidence}`);

        // Step 3: Try Smart Gemini AI extraction
        const gemini = getGeminiClient();
        if (gemini) {
            try {
                const smartResult = await extractWithSmartGemini(gemini, text);
                if (smartResult) {
                    const baseConfidence = ocrConfidence / 100;
                    return {
                        rawText: text,
                        docType: smartResult.classification.doc_type,
                        expiryDate: smartResult.entities.expiry_date,
                        dueDate: smartResult.entities.due_date,
                        amount: smartResult.entities.amount,
                        confidence: Math.min(Math.max(baseConfidence + 0.15, 0), 1),
                        extractionTrace: {
                            docType: {
                                method: 'ai',
                                matchedPattern: 'gemini-1.5-flash',
                                rawSnippet: smartResult.classification.reasoning,
                            },
                            date: smartResult.entities.expiry_date
                                ? { method: 'ai', matchedPattern: 'gemini-1.5-flash', rawSnippet: String(smartResult.entities.expiry_date) }
                                : undefined,
                            amount: smartResult.entities.amount !== undefined
                                ? { method: 'ai', matchedPattern: 'gemini-1.5-flash', rawSnippet: String(smartResult.entities.amount) }
                                : undefined,
                        },
                        intelligence: smartResult,
                    };
                }
            } catch (aiErr: any) {
                console.warn('[OCR] Smart Gemini failed, falling back to regex:', aiErr.message);
            }
        }

        // Step 3: Regex/keyword fallback (no intelligence payload)
        return regexFallback(text, ocrConfidence);

    } catch (error) {
        console.error('[OCR] Processing failed:', error);
        return { rawText: '', docType: 'unknown', confidence: 0, extractionTrace: {} };
    }
};

//  Smart Gemini extractor ──────────────────────────────────────────────────────

const extractWithSmartGemini = async (
    client: GoogleGenerativeAI,
    rawText: string
): Promise<SmartIntelligence | null> => {
    const model = client.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const prompt = SMART_PROMPT(rawText);

    const result = await model.generateContent(prompt);
    const responseText = result.response.text().trim();
    const cleaned = responseText
        .replace(/^```json?\s*/i, '')
        .replace(/```\s*$/i, '')
        .trim();

    let parsed: any;
    try {
        parsed = JSON.parse(cleaned);
    } catch {
        console.warn('[OCR] Smart Gemini returned non-JSON:', responseText.slice(0, 150));
        return null;
    }

    // Validate doc_type is from allowed list — if not, fall back to Other
    const docType = ALLOWED_DOC_TYPES.includes(parsed.doc_type) ? parsed.doc_type : 'Other';
    const category = DOC_CATEGORIES.includes(parsed.category) ? parsed.category : 'Other';

    // Parse suggested events — filter out any without a valid date
    const suggested_events: Omit<ISuggestedEvent, 'accepted'>[] = (parsed.suggested_events || [])
        .map((e: any) => ({
            title: String(e.title || ''),
            date: parseGeminiDate(e.date),
            event_type: ['expiry', 'renewal', 'payment', 'follow_up', 'milestone'].includes(e.event_type)
                ? e.event_type
                : 'milestone',
            reason: String(e.reason || ''),
        }))
        .filter((e: any) => e.date instanceof Date && !isNaN(e.date.getTime()) && e.title);

    return {
        classification: {
            doc_type: docType,
            category,
            confidence: typeof parsed.confidence === 'number'
                ? Math.min(Math.max(parsed.confidence, 0), 1)
                : 0.5,
            reasoning: String(parsed.reasoning || ''),
        },
        entities: {
            person_name: parsed.entities?.person_name || undefined,
            id_number:   parsed.entities?.id_number   || undefined,
            issued_by:   parsed.entities?.issued_by   || undefined,
            issue_date:  parseGeminiDate(parsed.entities?.issue_date),
            expiry_date: parseGeminiDate(parsed.entities?.expiry_date),
            due_date:    parseGeminiDate(parsed.entities?.due_date),
            amount:      typeof parsed.entities?.amount === 'number' ? parsed.entities.amount : undefined,
            institution: parsed.entities?.institution || undefined,
            address:     parsed.entities?.address     || undefined,
        },
        tags: Array.isArray(parsed.tags)
            ? parsed.tags.slice(0, 6).map((t: any) => String(t).toLowerCase().replace(/[^a-z0-9\-]/g, ''))
            : [],
        importance: {
            score: typeof parsed.importance?.score === 'number'
                ? Math.min(Math.max(Math.round(parsed.importance.score), 1), 10)
                : 5,
            criticality: ['low', 'medium', 'high', 'critical'].includes(parsed.importance?.criticality)
                ? parsed.importance.criticality
                : 'medium',
            lifecycle_stage: String(parsed.importance?.lifecycle_stage || 'active'),
            renewal_window_days: typeof parsed.importance?.renewal_window_days === 'number'
                ? parsed.importance.renewal_window_days
                : undefined,
        },
        suggested_events,
        ai_model: 'gemini-1.5-flash',
        raw_ai_response: responseText,
    };
};

const parseGeminiDate = (value: any): Date | undefined => {
    if (!value || value === 'null') return undefined;
    const d = new Date(value);
    return isNaN(d.getTime()) ? undefined : d;
};

//  Regex / keyword fallback 

const regexFallback = (text: string, ocrConfidence: number): OcrResult => {
    const classification = classifyDocument(text);
    const dateResult     = extractDates(text);
    const amountResult   = extractAmount(text);

    let finalConfidence = ocrConfidence / 100;
    if (classification.score > 0.8)  finalConfidence += 0.1;
    if (dateResult.dates.length > 2) finalConfidence -= 0.15;

    const now = new Date();
    const expiryDate = dateResult.dates.length > 0 ? dateResult.dates[0] : undefined;
    if (expiryDate && expiryDate < now) finalConfidence -= 0.2;

    return {
        rawText: text,
        docType: classification.type,
        expiryDate,
        dueDate: dateResult.dates.length > 1 ? dateResult.dates[1] : undefined,
        amount:  amountResult.amount,
        confidence: Math.min(Math.max(finalConfidence, 0), 1),
        extractionTrace: {
            date:    dateResult.trace,
            amount:  amountResult.trace,
            docType: classification.trace,
        },
    };
};

const classifyDocument = (text: string): { type: string; score: number; trace: ExtractionTrace } => {
    const keywords: Record<string, string[]> = {
        electricity_bill: ['electricity', 'mseb', 'power', 'bill', 'unit', 'consumer', 'kwh'],
        insurance:        ['policy', 'insurance', 'premium', 'sum insured', 'validity', 'nominee'],
        passport:         ['passport', 'republic of india', 'nationality', 'p-ind', 'visa'],
        aadhaar:          ['aadhaar', 'unique identification', 'government of india', 'male', 'female'],
        driving_license:  ['license', 'driving', 'transport', 'license no', 'haz', 'invalid'],
        tax_return:       ['income tax', 'itr', 'tax return', 'assessment year', 'pan card'],
        pan_card:         ['permanent account number', 'pan', 'income tax department'],
        voter_id:         ['election commission', 'voter', 'electors photo'],
        vehicle_rc:       ['registration certificate', 'rc book', 'vehicle', 'chassis'],
        bank_statement:   ['account statement', 'transactions', 'balance', 'ifsc', 'bank'],
    };

    const lower = text.toLowerCase();
    let bestType = 'unknown', bestScore = 0;
    let matchedKeywords: string[] = [];

    for (const [type, keys] of Object.entries(keywords)) {
        const matched = keys.filter(k => lower.includes(k));
        const score = matched.length / keys.length;
        if (score > bestScore) { bestScore = score; bestType = type; matchedKeywords = matched; }
    }

    const firstKeyword = matchedKeywords[0] || '';
    const idx = lower.indexOf(firstKeyword);
    const rawSnippet = idx >= 0 ? text.slice(Math.max(0, idx - 10), idx + 40).trim() : '';

    return {
        type: bestType, score: bestScore,
        trace: { method: 'keyword', matchedPattern: matchedKeywords.slice(0, 3).join(', ') || 'none', rawSnippet },
    };
};

const extractDates = (text: string): { dates: Date[]; trace?: ExtractionTrace } => {
    const datePattern = /(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})|(\d{1,2})\s(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s(\d{2,4})/gi;
    const matches = text.match(datePattern) || [];
    if (matches.length === 0) return { dates: [] };

    const expiryLabelPattern = /(expir[^\n:]{0,15}:|valid(?:ity)?\s*(?:till|upto|date)?[^\n:]{0,10}:|due\s*date[^\n:]{0,5}:|renew[^\n:]{0,10}:)/i;
    const labelMatch = text.match(expiryLabelPattern);
    const rawSnippet = labelMatch
        ? text.slice(text.indexOf(labelMatch[0]), text.indexOf(labelMatch[0]) + 60).trim()
        : matches[0] ?? '';

    const dates = matches.map(m => {
        if (/[a-zA-Z]/.test(m)) return new Date(m);
        const parts = m.split(/[\/\-\.]/);
        let day = parseInt(parts[0]), month = parseInt(parts[1]), year = parseInt(parts[2]);
        if (year < 100) year += 2000;
        if (month > 12 && day <= 12) { [day, month] = [month, day]; }
        return new Date(year, month - 1, day);
    }).filter(d => !isNaN(d.getTime()));

    return {
        dates,
        trace: { method: 'regex', matchedPattern: labelMatch ? labelMatch[0].trim() : datePattern.source.slice(0, 40), rawSnippet },
    };
};

const extractAmount = (text: string): { amount?: number; trace?: ExtractionTrace } => {
    const amountRegex = /(?:rs\.?|inr|total|\u20b9|net payable|amount due)\s?(\d+(?:,\d+)*(?:\.\d{2})?)/i;
    const match = text.match(amountRegex);
    if (match) {
        return {
            amount: parseFloat(match[1].replace(/,/g, '')),
            trace: { method: 'regex', matchedPattern: match[0].split(/\d/)[0].trim(), rawSnippet: match[0].trim() },
        };
    }
    return { amount: undefined };
};
