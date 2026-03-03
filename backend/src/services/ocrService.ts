import Tesseract from 'tesseract.js';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { ALLOWED_DOC_TYPES, DOC_CATEGORIES, ISuggestedEvent } from '../models/DocumentIntelligence';
import https from 'https';
import http from 'http';
import sharp from 'sharp';

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
    // ── File nature detected from magic bytes ─────────────────────────────
    fileNature?: 'image' | 'scanned_pdf' | 'native_pdf' | 'unknown';
    // ── NEW: Smart intelligence payload (present when Gemini succeeds) ────────
    intelligence?: SmartIntelligence;
}

export interface SmartIntelligence {
    document_classification: {
        document_type: string | null;
        category: string | null;
        subcategory: string | null;
        confidence: number;
    };
    entities: {
        people: Array<{ name: string | null; role: string | null; confidence: number }>;
        organizations: Array<{ name: string | null; type: string | null; confidence: number }>;
        id_numbers: Array<{ value: string | null; type: string | null; confidence: number }>;
        financial_details: {
            amounts: Array<{ value: number; currency: string; confidence: number }>;
            account_numbers: Array<{ value: string | null; confidence: number }>;
        };
        important_dates: Array<{ label: string | null; value: string | null; confidence: number }>;
        locations: Array<{ value: string | null; confidence: number }>;
    };
    document_flags: {
        is_identity_document: boolean;
        is_financial_document: boolean;
        is_legal_document: boolean;
        is_medical_document: boolean;
        is_educational_document: boolean;
        is_business_document: boolean;
    };
    risk_analysis: {
        is_expired: boolean | null;
        expires_within_6_months: boolean | null;
        missing_critical_fields: string[];
        risk_level: 'low' | 'medium' | 'high' | null;
    };
    brief_summary: string; // Brief natural language overview for future AI bot
    tags: string[];
    importance: {
        score: number;
        criticality: 'low' | 'medium' | 'high';
    };
    suggested_events: Array<{
        title: string | null;
        date: string | null;
        event_type: 'expiry' | 'renewal' | 'payment' | 'milestone' | 'issue' | 'other';
        confidence: number;
    }>;
    overall_confidence: number;
    ai_model: string;
    raw_ai_response: string;
}

//  Gemini client ───────────────────────────────────────────────────────────────

export const getGeminiClient = () => {
    const key = process.env.GEMINI_API_KEY;
    if (!key || key === 'your_gemini_api_key_here') return null;
    return new GoogleGenerativeAI(key);
};

// ── Smart prompt ──────────────────────────────────────────────────────────────

const SMART_PROMPT = (text: string, uploadDate: string) => `You are a Universal Smart Document Intelligence Engine for a secure family document management system used in India.

STRICT RULES:
1. Extract ONLY information clearly visible in the document.
2. Do NOT guess, assume, or infer missing values.
3. If a value is not explicitly visible, return null.
4. Preserve numbers exactly as written.
5. Indian date format is DD/MM/YYYY. Convert all dates to ISO format YYYY-MM-DD.
6. Never swap day and month.
7. If multiple dates exist, classify them correctly (issue, expiry, payment, event, etc.).
8. If OCR quality seems unclear, reduce confidence scores.
9. Return STRICT JSON ONLY.
10. No explanations. No markdown. No extra text.

TODAY_DATE: ${uploadDate}

Analyze the attached document image. 
${text ? `Reference decrypted text if helpful: ${text.slice(0, 4000)}` : ''}

Return EXACT JSON in this structure:

{
  "document_classification": {
    "document_type": null,
    "category": null,
    "subcategory": null,
    "confidence": 0.0
  },

  "entities": {
    "people": [
      { "name": null, "role": null, "confidence": 0.0 }
    ],
    "organizations": [
      { "name": null, "type": null, "confidence": 0.0 }
    ],
    "id_numbers": [
      { "value": null, "type": null, "confidence": 0.0 }
    ],
    "financial_details": {
      "amounts": [
        { "value": 0.0, "currency": "INR", "confidence": 0.0 }
      ],
      "account_numbers": [
        { "value": null, "confidence": 0.0 }
      ]
    },
    "important_dates": [
      { "label": null, "value": "YYYY-MM-DD", "confidence": 0.0 }
    ],
    "locations": [
      { "value": null, "confidence": 0.0 }
    ]
  },

  "document_insights": {
    "purpose": "Brief description of document intent (e.g. This is a medical lab report from SRL Diagnostics showing lipid profile results for Jeel Kanani)",
    "is_identity_document": false,
    "is_financial_document": false,
    "is_legal_document": false,
    "is_medical_document": false,
    "is_educational_document": false,
    "is_business_document": false
  },

  "risk_analysis": {
    "is_expired": null,
    "expires_within_6_months": null,
    "missing_critical_fields": [],
    "risk_level": null
  },

  "tags": [],

  "importance": {
    "score": 1,
    "criticality": "low"
  },

  "suggested_events": [
    {
      "title": null,
      "date": "YYYY-MM-DD",
      "event_type": "expiry/renewal/payment/milestone/issue/other",
      "confidence": 0.0
    }
  ],

  "brief_summary": "One sentence summary that includes key entities and purpose. Crucial for a future AI bot to find this document.",
  "overall_confidence": 0.0
}

CRITICAL:
- There MUST be at least 1 object inside suggested_events.
- If no valid date is found in the document, create a milestone event using TODAY_DATE.
- All confidence values must be between 0.0 and 1.0.
- Mark sensitive documents tags as: "identity_critical", "financial_critical", or "general".
`;


// ── Clean OCR artifacts before sending to AI ─────────────────────────────────

// ── Image Resizing with sharp ───────────────────────────────────────────────
/**
 * Resizes an image to a maximum dimension (width or height) of 1600px.
 * This reduces upload/cloud costs and improves processing speed while
 * maintaining enough detail for AI vision.
 */
async function resizeImage(buffer: Buffer, maxDim = 1600): Promise<Buffer> {
    try {
        const metadata = await sharp(buffer).metadata();
        if (!metadata.width || !metadata.height) return buffer;

        if (metadata.width <= maxDim && metadata.height <= maxDim) {
            // Still normalize format — convert HEIC/TIFF to JPEG for Gemini compatibility
            // but keep PNG as PNG to preserve transparency if needed
            const format = metadata.format;
            if (format === 'png') {
                return await sharp(buffer).png({ quality: 90 }).toBuffer();
            }
            return await sharp(buffer).jpeg({ quality: 90 }).toBuffer();
        }

        console.log(`[OCR] Resizing image from ${metadata.width}x${metadata.height} to max ${maxDim}px`);

        const pipeline = sharp(buffer)
            .resize(maxDim, maxDim, {
                fit: 'inside',
                withoutEnlargement: true
            });

        // Preserve PNG format, convert everything else to JPEG
        if (metadata.format === 'png') {
            return await pipeline.png({ quality: 90 }).toBuffer();
        }
        return await pipeline.jpeg({ quality: 90 }).toBuffer();
    } catch (err: any) {
        console.warn(`[OCR] Resizing failed, using original: ${err.message}`);
        return buffer;
    }
}

function cleanOcrText(raw: string): string {
    return raw
        // Remove repeated whitespace/newlines but keep structure
        .replace(/[ \t]{2,}/g, ' ')
        .replace(/\n{3,}/g, '\n\n')
        // Remove non-printable control characters
        .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '')
        // Fix common Tesseract confusions
        .replace(/\b0(?=[A-Z])/g, 'O')      // 0BC → OBC
        .replace(/(?<=[A-Z])0\b/g, 'O')     // AB0 → ABO
        // Normalize Indian date separators (- and . → /)
        .replace(/(\d{1,2})[-.](\d{1,2})[-.](\d{4})/g, '$1/$2/$3')
        .trim();
}

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
const transformUrlForOcr = (fileUrl: string, page = 1): string => {
    const lower = fileUrl.toLowerCase();
    if (lower.includes('.pdf') && fileUrl.includes('/upload/')) {
        // q_100 = max quality, w_2480 = A4 at 300dpi, sharpen for OCR
        return fileUrl.replace('/upload/', `/upload/f_jpg,pg_${page},q_100,w_2480,e_sharpen:100/`);
    }
    // For images: upscale small images and sharpen
    if (fileUrl.includes('/upload/')) {
        return fileUrl.replace('/upload/', '/upload/w_2480,q_100,e_sharpen:100/');
    }
    return fileUrl;
};
// ── File Nature Detection (magic bytes) ───────────────────────────────────────
//
// Detects the real nature of a file from its raw bytes — not the URL extension.
// Used so the pipeline can route each file to the most appropriate extraction path.
//
// Returns:
//   'image'       — JPEG / PNG / WebP / GIF (already rasterised, run Tesseract)
//   'scanned_pdf' — PDF whose first page returned < 80 chars (no text layer, run Tesseract)
//   'native_pdf'  — PDF with a real text layer (skip Tesseract, use text directly)
//   'unknown'     — unrecognised bytes (fall back to Tesseract)
//
export function detectFileNature(
    rawBuffer: Buffer,
    extractedTextLength: number,
    originalUrl?: string
): OcrResult['fileNature'] {
    // PDFs are transformed to JPEG by Cloudinary before download,
    // so magic bytes will show JPEG even for PDFs.
    // Use the original URL extension as the primary PDF signal.
    if (originalUrl && originalUrl.toLowerCase().includes('.pdf')) {
        return extractedTextLength >= 80 ? 'native_pdf' : 'scanned_pdf';
    }

    if (rawBuffer.length < 4) return 'unknown';

    const sig = rawBuffer.subarray(0, 4);

    // JPEG: FF D8 FF
    if (sig[0] === 0xFF && sig[1] === 0xD8 && sig[2] === 0xFF) return 'image';
    // PNG: 89 50 4E 47
    if (sig[0] === 0x89 && sig[1] === 0x50 && sig[2] === 0x4E && sig[3] === 0x47) return 'image';
    // GIF: 47 49 46 38
    if (sig[0] === 0x47 && sig[1] === 0x49 && sig[2] === 0x46 && sig[3] === 0x38) return 'image';
    // WebP: 52 49 46 46 (RIFF header)
    if (sig[0] === 0x52 && sig[1] === 0x49 && sig[2] === 0x46 && sig[3] === 0x46) return 'image';
    // Raw PDF bytes (not via Cloudinary transform)
    if (sig[0] === 0x25 && sig[1] === 0x50 && sig[2] === 0x44 && sig[3] === 0x46) {
        return extractedTextLength >= 80 ? 'native_pdf' : 'scanned_pdf';
    }

    return 'unknown';
}

/**
 * Phase 6 - Direct Vision Extraction
 * Sends image bytes directly to Gemini 1.5 Flash.
 * This skips local OCR entirely and gets the final JSON in one pass.
 */
export const extractWithGeminiVision = async (
    client: GoogleGenerativeAI,
    imageBuffer: Buffer,
    uploadDate: string
): Promise<SmartIntelligence | null> => {
    // Detect mimeType from magic bytes
    let mimeType = 'image/jpeg';
    if (imageBuffer.length > 4) {
        const sig = imageBuffer.subarray(0, 4);
        if (sig[0] === 0x89 && sig[1] === 0x50 && sig[2] === 0x4E && sig[3] === 0x47) mimeType = 'image/png';
        else if (sig[0] === 0x47 && sig[1] === 0x49 && sig[2] === 0x46 && sig[3] === 0x38) mimeType = 'image/gif';
        else if (sig[0] === 0x52 && sig[1] === 0x49 && sig[2] === 0x46 && sig[3] === 0x46) mimeType = 'image/webp';
    }
    const models = ['gemini-2.0-flash', 'gemini-1.5-flash'];

    for (const modelName of models) {
        try {
            const model = client.getGenerativeModel({
                model: modelName,
                generationConfig: { temperature: 0.1, topP: 0.8, maxOutputTokens: 4096 },
            });

            // Convert buffer to base64 for Gemini vision
            const imagePart = {
                inlineData: {
                    data: imageBuffer.toString('base64'),
                    mimeType
                }
            };

            console.log(`[OCR-Vision] Sending ${(imageBuffer.length / 1024).toFixed(0)}KB ${mimeType} to ${modelName}`);
            const result = await model.generateContent([SMART_PROMPT('', uploadDate), imagePart]);
            const responseText = result.response.text().trim();
            console.log(`[OCR-Vision] ${modelName} responded (${responseText.length} chars)`);

            const parsed = parseGeminiResponse(responseText, modelName);
            if (parsed) return parsed;
            console.warn(`[OCR-Vision] ${modelName} response could not be parsed`);
        } catch (err: any) {
            console.error(`[OCR-Vision] ${modelName} FAILED: ${err.message}`);
        }
    }
    return null;
};

/** Shared parser for Gemini JSON responses */
function parseGeminiResponse(responseText: string, modelName: string): SmartIntelligence | null {
    const cleaned = responseText
        .replace(/^```json?\s*/i, '')
        .replace(/```\s*$/i, '')
        .trim();

    let parsed: any;
    const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
    try {
        parsed = JSON.parse(jsonMatch ? jsonMatch[0] : cleaned);
    } catch (parseErr: any) {
        console.warn(`[OCR] ${modelName} non-JSON response:`, responseText.slice(0, 300));
        return null;
    }

    // Map user-requested structure to our SmartIntelligence interface
    // (In this case, the interface matches the requested structure exactly)

    const suggested_events = (parsed.suggested_events || [])
        .map((e: any) => ({
            title: String(e.title || ''),
            date: parseGeminiDate(e.date),
            event_type: ['expiry', 'renewal', 'payment', 'milestone', 'issue', 'other'].includes(e.event_type)
                ? e.event_type : 'milestone',
            confidence: typeof e.confidence === 'number' ? e.confidence : 0.5,
        }))
        .filter((e: any) => e.date instanceof Date && !isNaN(e.date.getTime()) && e.title);

    return {
        document_classification: {
            document_type: parsed.document_classification?.document_type || 'Other',
            category: parsed.document_classification?.category || 'Other',
            subcategory: parsed.document_classification?.subcategory || null,
            confidence: typeof parsed.document_classification?.confidence === 'number'
                ? parsed.document_classification.confidence : 0.5,
        },
        entities: {
            people: Array.isArray(parsed.entities?.people) ? parsed.entities.people : [],
            organizations: Array.isArray(parsed.entities?.organizations) ? parsed.entities.organizations : [],
            id_numbers: Array.isArray(parsed.entities?.id_numbers) ? parsed.entities.id_numbers : [],
            financial_details: {
                amounts: Array.isArray(parsed.entities?.financial_details?.amounts)
                    ? parsed.entities.financial_details.amounts : [],
                account_numbers: Array.isArray(parsed.entities?.financial_details?.account_numbers)
                    ? parsed.entities.financial_details.account_numbers : [],
            },
            important_dates: Array.isArray(parsed.entities?.important_dates) ? parsed.entities.important_dates : [],
            locations: Array.isArray(parsed.entities?.locations) ? parsed.entities.locations : [],
        },
        document_flags: {
            is_identity_document: !!(parsed.document_insights?.is_identity_document || parsed.document_flags?.is_identity_document),
            is_financial_document: !!(parsed.document_insights?.is_financial_document || parsed.document_flags?.is_financial_document),
            is_legal_document: !!(parsed.document_insights?.is_legal_document || parsed.document_flags?.is_legal_document),
            is_medical_document: !!(parsed.document_insights?.is_medical_document || parsed.document_flags?.is_medical_document),
            is_educational_document: !!(parsed.document_insights?.is_educational_document || parsed.document_flags?.is_educational_document),
            is_business_document: !!(parsed.document_insights?.is_business_document || parsed.document_flags?.is_business_document),
        },
        risk_analysis: {
            is_expired: parsed.risk_analysis?.is_expired ?? null,
            expires_within_6_months: parsed.risk_analysis?.expires_within_6_months ?? null,
            missing_critical_fields: Array.isArray(parsed.risk_analysis?.missing_critical_fields)
                ? parsed.risk_analysis.missing_critical_fields : [],
            risk_level: ['low', 'medium', 'high'].includes(parsed.risk_analysis?.risk_level)
                ? parsed.risk_analysis.risk_level : null,
        },
        brief_summary: String(parsed.brief_summary || parsed.document_insights?.purpose || 'No summary available'),
        tags: Array.isArray(parsed.tags) ? parsed.tags : [],
        importance: {
            score: typeof parsed.importance?.score === 'number' ? parsed.importance.score : 5,
            criticality: ['low', 'medium', 'high'].includes(parsed.importance?.criticality)
                ? parsed.importance.criticality : 'medium',
        },
        suggested_events: suggested_events.map((e: any) => ({
            ...e,
            date: e.date.toISOString().split('T')[0] // Convert back to string for the interface
        })),
        overall_confidence: typeof parsed.overall_confidence === 'number' ? parsed.overall_confidence : 0.5,
        ai_model: modelName,
        raw_ai_response: responseText,
    };
}

//  Main entry point ────────────────────────────────────────────────────────────

export const processDocumentOcr = async (fileUrl: string): Promise<OcrResult> => {
    try {
        const isPdf = fileUrl.toLowerCase().includes('.pdf');
        const uploadDate = new Date().toISOString().slice(0, 10);
        const gemini = getGeminiClient();

        // ── Step 1: Download & Initial Resize ────────────────────────────────
        const ocrUrl = transformUrlForOcr(fileUrl, 1);
        const rawBuffer = await downloadToBuffer(ocrUrl);
        const resizedBuffer = await resizeImage(rawBuffer);

        // ── Detect file nature from magic bytes + URL ──────────────────────
        // We pass 0 as text length because we haven't run OCR yet
        const fileNature = detectFileNature(resizedBuffer, 0, fileUrl);
        console.log(`[OCR] File nature: ${fileNature} | url=${fileUrl.slice(-50)}`);

        // ── Step 2: STRATEGY A - Direct Gemini Vision (FASTEST) ──────────────
        // If it's an image or scanned PDF and we have Gemini, go direct.
        if (gemini && (fileNature === 'image' || fileNature === 'scanned_pdf' || fileNature === 'unknown')) {
            console.log(`[OCR] Strategy A: Direct Gemini Vision | buffer=${resizedBuffer.length} bytes`);
            try {
                const smartResult = await extractWithGeminiVision(gemini, resizedBuffer, uploadDate);
                if (smartResult) {
                    console.log(`[OCR] ✓ Strategy A succeeded | type=${smartResult.document_classification.document_type} | confidence=${(smartResult.overall_confidence * 100).toFixed(0)}%`);
                    return finalizeOcrResult(smartResult, '', smartResult.overall_confidence, fileNature);
                }
                console.warn('[OCR] Strategy A returned null — Gemini gave no usable response');
            } catch (err: any) {
                console.warn(`[OCR] Strategy A failed: ${err.message}`);
            }
        } else {
            console.log(`[OCR] Skipping Strategy A: gemini=${!!gemini}, fileNature=${fileNature}`);
        }

        // ── Step 3: STRATEGY B - Tesseract + Gemini (Fallback) ────────────────
        console.log('[OCR] Strategy B: Local Tesseract OCR extraction fallback');
        const { text: ocrText, ocrConfidence } = await runTesseractOnBuffer(resizedBuffer);

        let finalText = ocrText;
        if (isPdf && ocrText.trim().length < 200) {
            console.log('[OCR] Page 1 sparse — attempting page 2 for Strategy B');
            try {
                // For page 2, we just use the old helper which does its own download/resize
                const page2 = await extractTextFromUrl(fileUrl, 2);
                finalText = `${ocrText}\n---PAGE2---\n${page2.text}`;
            } catch { /* page 2 optional */ }
        }

        if (gemini && finalText.trim().length > 10) {
            try {
                const smartResult = await extractWithSmartGemini(gemini, finalText, uploadDate);
                if (smartResult) {
                    return finalizeOcrResult(smartResult, finalText, ocrConfidence / 100, fileNature);
                }
            } catch { /* fallback to regex */ }
        }

        // ── Step 4: Strategy C - Regex Fallback ───────────────────────────────
        console.log('[OCR] Strategy C: Final Regex Fallback');
        return { ...regexFallback(finalText, ocrConfidence), fileNature };

    } catch (error: any) {
        console.error('[OCR] Processing failed:', error.message);
        return { rawText: '', docType: 'unknown', confidence: 0, extractionTrace: {}, fileNature: 'unknown' };
    }
};

/** Shared finalizer for Gemini-based results */
function finalizeOcrResult(
    smartResult: SmartIntelligence,
    rawText: string,
    baseConfidence: number,
    fileNature: OcrResult['fileNature']
): OcrResult {
    const aiConfidence = smartResult.document_classification.confidence;

    // For direct vision (base=0.9), we trust the AI confidence but allow a slight boost
    // if the model itself is very sure.
    const boostedConfidence = aiConfidence > 0.9
        ? Math.min(baseConfidence + 0.1, 1.0)
        : aiConfidence;

    // Extraction trace needs to map some best-guess fields
    // We'll use the first entries from the smarter arrays
    const mainPerson = smartResult.entities.people[0];
    const mainOrg = smartResult.entities.organizations[0];
    const mainAmount = smartResult.entities.financial_details.amounts[0];

    return {
        rawText,
        docType: smartResult.document_classification.document_type || 'Other',
        // Note: Field mapping for legacy UI happens in OcrResult mapping
        confidence: boostedConfidence,
        extractionTrace: {
            docType: {
                method: 'ai',
                matchedPattern: smartResult.ai_model,
                rawSnippet: `Type: ${smartResult.document_classification.document_type}, Cat: ${smartResult.document_classification.category}`,
            },
            date: smartResult.entities.important_dates[0]
                ? { method: 'ai', matchedPattern: smartResult.ai_model, rawSnippet: 'ext-date' }
                : undefined,
            amount: mainAmount
                ? { method: 'ai', matchedPattern: smartResult.ai_model, rawSnippet: 'ext-amt' }
                : undefined,
        },
        intelligence: smartResult,
        fileNature,
    };
}

// ── Run Tesseract on Buffer ──────────────────────────────────────────────────
/**
 * Runs Tesseract OCR on a provided image buffer.
 * Includes sharp preprocessing for better accuracy.
 */
async function runTesseractOnBuffer(imageBuffer: Buffer): Promise<{ text: string; ocrConfidence: number }> {
    let processed: Buffer;
    try {
        processed = await sharp(imageBuffer)
            .grayscale()
            .normalise()
            .linear(1.2, -20)
            .sharpen({ sigma: 1.5 })
            .toBuffer();
    } catch {
        processed = imageBuffer;
    }

    try {
        // We use @ts-ignore because Tesseract.js types sometimes lag behind accepted worker params
        const result = await Tesseract.recognize(processed, 'eng+hin', {
            // @ts-ignore
            tessedit_pageseg_mode: '6',
        });
        return { text: result.data.text, ocrConfidence: result.data.confidence };
    } catch (err: any) {
        console.warn(`[OCR] Tesseract eng+hin failed: ${err.message}. Retrying eng only.`);
        const fallback = await Tesseract.recognize(processed, 'eng', {
            // @ts-ignore
            tessedit_pageseg_mode: '6',
        });
        return { text: fallback.data.text, ocrConfidence: fallback.data.confidence };
    }
}

async function extractTextFromUrl(fileUrl: string, page: number): Promise<{ text: string; ocrConfidence: number; rawBuffer?: Buffer }> {
    const ocrUrl = transformUrlForOcr(fileUrl, page);
    console.log(`[OCR] Downloading page ${page} | ${ocrUrl.slice(0, 90)}…`);

    const rawBuffer = await downloadToBuffer(ocrUrl);
    const resized = await resizeImage(rawBuffer);
    const { text, ocrConfidence } = await runTesseractOnBuffer(resized);

    return { text, ocrConfidence, rawBuffer: resized };
}

//  Smart Gemini extractor ──────────────────────────────────────────────────────

export const extractWithSmartGemini = async (
    client: GoogleGenerativeAI,
    rawText: string,
    uploadDate: string
): Promise<SmartIntelligence | null> => {
    const models = ['gemini-2.0-flash', 'gemini-1.5-flash'];

    for (const modelName of models) {
        try {
            const model = client.getGenerativeModel({
                model: modelName,
                generationConfig: { temperature: 0.1, topP: 0.8, maxOutputTokens: 2048 },
            });
            const result = await model.generateContent(SMART_PROMPT(rawText, uploadDate));
            const responseText = result.response.text().trim();
            console.log(`[OCR] Gemini model=${modelName} responded (${responseText.length} chars)`);

            return parseGeminiResponse(responseText, modelName);
        } catch (err: any) {
            console.error(`[OCR] Gemini model=${modelName} FAILED: ${err.message}`);
        }
    }

    console.error('[OCR] All Gemini models failed — falling back to regex only');
    return null;
};

const parseGeminiDate = (value: any): Date | undefined => {
    if (!value || value === 'null' || value === 'undefined') return undefined;

    const str = String(value).trim();

    // AI always returns YYYY-MM-DD per prompt instructions
    const isoMatch = str.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (isoMatch) {
        const [, y, m, d] = isoMatch.map(Number);
        // Sanity check: year between 1950 and 2100, valid month/day
        if (y >= 1950 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            const date = new Date(y, m - 1, d);
            return isNaN(date.getTime()) ? undefined : date;
        }
    }

    // Fallback: try native parse
    const d = new Date(str);
    return isNaN(d.getTime()) ? undefined : d;
};

//  Regex / keyword fallback 

const regexFallback = (text: string, ocrConfidence: number): OcrResult => {
    const classification = classifyDocument(text);
    const dateResult = extractDates(text);
    const amountResult = extractAmount(text);

    let finalConfidence = ocrConfidence / 100;
    if (classification.score > 0.8) finalConfidence += 0.1;
    if (dateResult.dates.length > 2) finalConfidence -= 0.15;

    const now = new Date();
    const expiryDate = dateResult.dates.length > 0 ? dateResult.dates[0] : undefined;
    if (expiryDate && expiryDate < now) finalConfidence -= 0.2;

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
            docType: classification.trace,
        },
    };
};

const classifyDocument = (text: string): { type: string; score: number; trace: ExtractionTrace } => {
    const keywords: Record<string, string[]> = {
        electricity_bill: ['electricity', 'mseb', 'power', 'bill', 'unit', 'consumer', 'kwh'],
        insurance: ['policy', 'insurance', 'premium', 'sum insured', 'validity', 'nominee'],
        passport: ['passport', 'republic of india', 'nationality', 'p-ind', 'visa'],
        aadhaar: ['aadhaar', 'unique identification', 'government of india', 'male', 'female'],
        driving_license: ['license', 'driving', 'transport', 'license no', 'haz', 'invalid'],
        tax_return: ['income tax', 'itr', 'tax return', 'assessment year', 'pan card'],
        pan_card: ['permanent account number', 'pan', 'income tax department'],
        voter_id: ['election commission', 'voter', 'electors photo'],
        vehicle_rc: ['registration certificate', 'rc book', 'vehicle', 'chassis'],
        bank_statement: ['account statement', 'transactions', 'balance', 'ifsc', 'bank'],
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
