import Tesseract from 'tesseract.js';
import { GoogleGenerativeAI } from '@google/generative-ai';

//  Types 

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
    confidence: number;
    extractionTrace: {
        date?: ExtractionTrace;
        amount?: ExtractionTrace;
        docType?: ExtractionTrace;
    };
}

//  Gemini client 

const getGeminiClient = () => {
    const key = process.env.GEMINI_API_KEY;
    if (!key || key === 'your_gemini_api_key_here') return null;
    return new GoogleGenerativeAI(key);
};

//  Main entry point 

export const processDocumentOcr = async (fileUrl: string): Promise<OcrResult> => {
    try {
        // Step 1: Tesseract � pixel to raw text
        const { data: { text, confidence: ocrConfidence } } = await Tesseract.recognize(fileUrl, 'eng+hin');

        if (!text || text.trim().length < 10) {
            return { rawText: text || '', docType: 'unknown', confidence: 0, extractionTrace: {} };
        }

        // Step 2: Try Gemini AI extraction
        const gemini = getGeminiClient();
        if (gemini) {
            try {
                const aiResult = await extractWithGemini(gemini, text);
                if (aiResult) {
                    const baseConfidence = ocrConfidence / 100;
                    return {
                        rawText: text,
                        docType: aiResult.docType || 'unknown',
                        expiryDate: aiResult.expiryDate,
                        dueDate: aiResult.dueDate,
                        amount: aiResult.amount,
                        confidence: Math.min(Math.max(baseConfidence + 0.15, 0), 1),
                        extractionTrace: {
                            docType: { method: 'ai', matchedPattern: 'gemini-1.5-flash', rawSnippet: aiResult.docType || '' },
                            date: aiResult.expiryDate
                                ? { method: 'ai', matchedPattern: 'gemini-1.5-flash', rawSnippet: aiResult.expiryDate.toISOString() }
                                : undefined,
                            amount: aiResult.amount !== undefined
                                ? { method: 'ai', matchedPattern: 'gemini-1.5-flash', rawSnippet: String(aiResult.amount) }
                                : undefined,
                        },
                    };
                }
            } catch (aiErr: any) {
                console.warn('[OCR] Gemini failed, falling back to regex:', aiErr.message);
            }
        }

        // Step 3: Regex/keyword fallback
        return regexFallback(text, ocrConfidence);

    } catch (error) {
        console.error('[OCR] Processing failed:', error);
        return { rawText: '', docType: 'unknown', confidence: 0, extractionTrace: {} };
    }
};

//  Gemini extraction 

interface GeminiExtracted {
    docType: string;
    expiryDate?: Date;
    dueDate?: Date;
    amount?: number;
}

const extractWithGemini = async (client: GoogleGenerativeAI, rawText: string): Promise<GeminiExtracted | null> => {
    const model = client.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `You are a document parser specializing in Indian documents.
Analyze the following text extracted from a scanned document and return a JSON object.

Rules:
- "docType": one of: aadhaar, pan_card, passport, driving_license, voter_id, electricity_bill, water_bill, gas_bill, insurance, bank_statement, salary_slip, tax_return, birth_certificate, marksheet, degree, property_deed, medical_record, vehicle_rc, unknown
- "expiryDate": ISO 8601 date string (YYYY-MM-DD) or null
- "dueDate": ISO 8601 date string (YYYY-MM-DD) or null - for bills, the payment due date
- "amount": number or null - payable amount in INR (digits only)

Return ONLY valid JSON. No explanation. No markdown. No code blocks.
Example: {"docType":"electricity_bill","expiryDate":null,"dueDate":"2025-03-15","amount":1284.50}

Document text:
${rawText.slice(0, 3000)}`;

    const result = await model.generateContent(prompt);
    const responseText = result.response.text().trim();
    // Strip markdown code fences if Gemini wraps response in ```json ... ```
    const cleaned = responseText.replace(/^```json?\s*/i, '').replace(/```\s*$/i, '').trim();

    let parsed: any;
    try {
        parsed = JSON.parse(cleaned);
    } catch {
        console.warn('[OCR] Gemini returned non-JSON:', responseText.slice(0, 100));
        return null;
    }

    return {
        docType:    typeof parsed.docType === 'string' ? parsed.docType : 'unknown',
        expiryDate: parseGeminiDate(parsed.expiryDate),
        dueDate:    parseGeminiDate(parsed.dueDate),
        amount:     typeof parsed.amount === 'number' ? parsed.amount : undefined,
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
