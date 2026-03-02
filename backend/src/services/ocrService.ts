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
    classification: {
        doc_type: string;
        category: string;
        confidence: number;
        reasoning: string;
    };
    entities: {
        person_name?: string;
        id_number?: string;                 // Aadhaar / PAN / passport number
        policy_number?: string;             // Insurance policy, vehicle RC
        registration_number?: string;       // Vehicle / company reg
        account_number?: string;            // Bank / loan account
        issued_by?: string;
        issue_date?: Date;
        expiry_date?: Date;
        due_date?: Date;
        amount?: number;
        institution?: string;
        address?: string;
        dob?: Date;                         // Date of birth from identity docs
        phone?: string;
        // Purchase / product fields
        purchase_date?: Date;               // When item was bought
        warranty_expiry_date?: Date;        // purchase date + warranty period
        product_name?: string;              // Laptop, fridge, phone, etc.
        seller_name?: string;               // Amazon, Flipkart, local store
        serial_number?: string;             // Product serial / IMEI
        warranty_years?: number;            // 1, 2, or 3 years
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

export const getGeminiClient = () => {
    const key = process.env.GEMINI_API_KEY;
    if (!key || key === 'your_gemini_api_key_here') return null;
    return new GoogleGenerativeAI(key);
};

// ── Smart prompt ──────────────────────────────────────────────────────────────

const SMART_PROMPT = (text: string, uploadDate: string) => `You are a Smart Document Intelligence Engine for a family document management app used in India.
Analyze the following OCR-extracted document text and return STRICT JSON only.
No markdown. No explanation. No code fences. Just raw JSON.

TODAY's date (document upload date): ${uploadDate}

IMPORTANT — Date format rules:
- Indian documents use DD/MM/YYYY format (e.g. "23/08/2028" means 23rd August 2028)
- You MUST output all dates as YYYY-MM-DD (ISO 8601)
- Example: "23/08/2028" → "2028-08-23", "01/01/2025" → "2025-01-01"
- Never swap day and month. DD comes first in Indian docs.

ALLOWED document types (pick the closest match):
${ALLOWED_DOC_TYPES.join(', ')}

ALLOWED categories: ${DOC_CATEGORIES.join(', ')}

Return this EXACT JSON structure with no extra keys:
{
  "doc_type": "string from allowed types",
  "category": "string from allowed categories",
  "confidence": 0.0 to 1.0,
  "reasoning": "one line explaining why you chose this type",
  "entities": {
    "person_name": "full name or null",
    "id_number": "Aadhaar/PAN/Passport/License number or null",
    "policy_number": "insurance policy number or vehicle RC or null",
    "registration_number": "vehicle registration or company reg or null",
    "account_number": "bank/loan account number or null",
    "issued_by": "issuing authority or null",
    "issue_date": "YYYY-MM-DD or null",
    "expiry_date": "YYYY-MM-DD or null",
    "due_date": "YYYY-MM-DD or null",
    "amount": number or null,
    "institution": "bank/org/seller name or null",
    "address": "address or null",
    "dob": "YYYY-MM-DD date of birth or null",
    "phone": "phone number or null",
    "purchase_date": "YYYY-MM-DD date of purchase for receipts/invoices or null",
    "warranty_expiry_date": "YYYY-MM-DD warranty end date or null (calculate: purchase_date + warranty_years if explicit, else purchase_date + 1 year for electronics)",
    "product_name": "specific item name, e.g. Dell Laptop, Samsung Galaxy S24, LG Refrigerator or null",
    "seller_name": "retailer/seller, e.g. Amazon, Croma, Reliance Digital, local shop name or null",
    "serial_number": "product serial number or IMEI or null",
    "warranty_years": warranty duration as number (1, 2, or 3) or null
  },
  "tags": ["max 6 lowercase tags, e.g. purchase, electronics, warranty, food, dining, medical, identity, travel, renewal-required, government, financial-risk, expired"],
  "importance": {
    "score": 1 to 10,
    "criticality": "low or medium or high or critical",
    "lifecycle_stage": "active or expiring-soon or expired or pending or completed",
    "renewal_window_days": number or null
  },
  "suggested_events": [
    {
      "title": "short action-oriented event title",
      "date": "YYYY-MM-DD",
      "event_type": "expiry or renewal or payment or follow_up or milestone",
      "reason": "why this event matters to the user"
    }
  ]
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRITICAL RULE: EVERY document MUST have AT LEAST 1 suggested_event.
If you cannot find any date in the document, use TODAY (${uploadDate}) as the event date with event_type="milestone".
NEVER return an empty suggested_events array.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Event generation rules by document type:

PURCHASE RECEIPTS / INVOICES / SHOPPING BILLS (laptop, phone, fridge, TV, AC, appliances, clothes, food, etc.):
  → ALWAYS add "X Purchased" milestone on purchase_date (or issue_date or today)
  → For electronics/appliances: add warranty expiry event (purchase_date + warranty_years, default 1 year for electronics if not specified)
  → For restaurants/food bills: add "Dining at X" milestone on bill date
  → For online shopping: add "Order Delivered" milestone on delivery/invoice date
  → For grocery: add "Grocery Shopping" milestone on bill date

IDENTITY DOCUMENTS (Aadhaar, PAN, Voter ID):
  → Add "Document Registered" milestone on issue_date if present
  → NO expiry events for permanent identity docs
  → Add DOB as "Birthday" milestone if dob is present and not already in family

EXPIRING DOCUMENTS (Passport, Driving License, Vehicle Insurance, Vehicle RC, Pollution Certificate):
  → Add expiry event on expiry_date (even if past)
  → Add renewal reminder: expiry_date minus renewal_window_days (Passport=180, License/Insurance/RC=60, Pollution=30)
  → Add "Document Issued" milestone on issue_date

INSURANCE (health, life, vehicle, home):
  → Add "Premium Due" payment event on due_date or annually calculated date
  → Add expiry/renewal events
  → Add "Policy Taken" milestone on issue_date

BILLS (electricity, water, gas, internet, mobile, maintenance):
  → Add "Bill Due" payment event on due_date
  → Add "Bill Received" milestone on issue_date
  → If no due_date but issue_date exists: set due_date = issue_date + 15 days

SALARY SLIPS:
  → Add "Salary Credited" milestone on issue_date (the month/date on the slip)

BANK STATEMENTS:
  → Add "Statement Period" milestone on issue_date or statement end date

TAX RETURNS (ITR):
  → Add "Tax Filed" milestone on filing date or issue_date
  → Add "Assessment Year Due" follow_up for next July 31st

LOAN AGREEMENTS:
  → Add "Loan Disbursed" milestone on issue_date
  → Add "EMI Due" payment event on next EMI date if mentioned
  → Add "Loan Closure" milestone on final payment date if mentioned

RENT AGREEMENTS:
  → Add "Agreement Started" milestone on start/issue date
  → Add "Agreement Expires" expiry event on end date
  → Add "Rent Due" milestone for 1st of next month if monthly rent is mentioned

MEDICAL (prescriptions, lab reports, discharge summaries, vaccination records):
  → Prescription: add "Prescription Issued" milestone on date + "Medicine Refill" follow_up in 30 days if chronic medication
  → Lab Report: add "Test Completed" milestone on test date + "Doctor Consultation" follow_up in 7 days
  → Vaccination: add "Vaccinated" milestone on vaccination date + "Next Dose Due" follow_up if schedule mentioned
  → Discharge Summary: add "Discharged" milestone on discharge date + "Follow-up Visit" follow_up in 14 days

ACADEMIC (marksheets, degrees, admission letters, fee receipts):
  → Marksheet/Degree: add "Result Published" or "Degree Awarded" milestone on issue_date
  → Admission Letter: add "Admission" milestone + "Semester Start" follow_up
  → Fee Receipt: add "Fee Paid" milestone on payment date

EMPLOYMENT (offer letters, appointment letters, experience letters, relieving):
  → Offer Letter: add "Job Offer Received" milestone on issue_date + "Joining Date" milestone on joining date
  → Appointment Letter: add "Employment Started" milestone on joining date  
  → Experience/Relieving Letter: add "Employment Ended" milestone on last working day

PROPERTY (deeds, rent agreements, NOC, affidavits):
  → Add "Document Created" milestone on issue/registration date
  → Rent Agreement: add start + expiry + monthly rent milestone

VEHICLE:
  → RC: add "Vehicle Registered" milestone on issue_date + registration expiry event
  → Pollution Certificate: add issue milestone + expiry (valid 1-2 years from issue)
  → Vehicle Insurance: add "Insurance Active" milestone + expiry + renewal reminder

ANY DOCUMENT (absolute fallback — use this if no other rule matches):
  → Add "[Document Title] Added" milestone using today's date (${uploadDate})
  → This guarantees every document appears on the timeline

DO NOT skip events because the date is in the past — past events show document history on the timeline.
DO NOT add events with null dates.
Maximum 4 events per document.

Indian document hints:
- Aadhaar: 12-digit number, "आधार" in Hindi
- PAN: 10 char like ABCDE1234F
- Passport: starts with letter, 10 year validity from issue date
- Electronics receipts: look for model number, IMEI, serial no, invoice no
- Bill amounts: ₹, Rs., INR prefix

Document text (first 6000 chars):
${cleanOcrText(text).slice(0, 6000)}`;

// ── Clean OCR artifacts before sending to AI ─────────────────────────────────

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
        // q_100 = max quality, w_2480 = A4 at 300dpi, sharpen for Tesseract
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
//  Main entry point ────────────────────────────────────────────────────────────

export const processDocumentOcr = async (fileUrl: string): Promise<OcrResult> => {
    try {
        const isPdf = fileUrl.toLowerCase().includes('.pdf');

        // ── Step 1: Download + Preprocess image ─────────────────────────────
        const { text, ocrConfidence, rawBuffer } = await extractTextFromUrl(fileUrl, 1);

        // ── Detect file nature from magic bytes + URL ──────────────────────
        const fileNature = rawBuffer
            ? detectFileNature(rawBuffer, text.trim().length, fileUrl)
            : (isPdf ? 'scanned_pdf' : 'image');
        console.log(`[OCR] File nature: ${fileNature} | url=${fileUrl.slice(-50)}`);

        // For PDFs: if page 1 gave too little, try page 2 and merge
        let finalText = text;
        if (isPdf && text.trim().length < 200) {
            console.log('[OCR] Page 1 sparse — attempting page 2 extraction');
            try {
                const page2 = await extractTextFromUrl(fileUrl, 2);
                if (page2.text.trim().length > text.trim().length) {
                    finalText = `${text}\n---PAGE2---\n${page2.text}`;
                    console.log(`[OCR] Page 2 added ${page2.text.trim().length} extra chars`);
                }
            } catch { /* page 2 optional */ }
        }

        if (!finalText || finalText.trim().length < 10) {
            console.warn(`[OCR] Too little text extracted — possible blank/unreadable scan. Confidence: ${ocrConfidence}`);
            return { rawText: finalText || '', docType: 'unknown', confidence: 0, extractionTrace: {}, fileNature };
        }

        console.log(`[OCR] Extracted ${finalText.trim().length} chars total | Tesseract confidence: ${ocrConfidence.toFixed(1)}`);

        // ── Step 2: Smart Gemini AI extraction ──────────────────────────────
        const gemini = getGeminiClient();
        if (gemini) {
            try {
                const uploadDate = new Date().toISOString().slice(0, 10);
                const smartResult = await extractWithSmartGemini(gemini, finalText, uploadDate);
                if (smartResult) {
                    const baseConfidence = ocrConfidence / 100;
                    const boostedConfidence = Math.min(
                        Math.max(baseConfidence + (smartResult.classification.confidence > 0.8 ? 0.2 : 0.1), 0),
                        1
                    );
                    console.log(
                        `[OCR] Gemini analysis complete | type=${smartResult.classification.doc_type} ` +
                        `| ai-confidence=${(smartResult.classification.confidence * 100).toFixed(0)}% ` +
                        `| events=${smartResult.suggested_events.length}`
                    );
                    return {
                        rawText: finalText,
                        docType: smartResult.classification.doc_type,
                        expiryDate: smartResult.entities.expiry_date,
                        dueDate: smartResult.entities.due_date,
                        amount: smartResult.entities.amount,
                        confidence: boostedConfidence,
                        extractionTrace: {
                            docType: {
                                method: 'ai',
                                matchedPattern: 'gemini-2.0-flash',
                                rawSnippet: smartResult.classification.reasoning,
                            },
                            date: smartResult.entities.expiry_date
                                ? { method: 'ai', matchedPattern: 'gemini-2.0-flash', rawSnippet: String(smartResult.entities.expiry_date) }
                                : undefined,
                            amount: smartResult.entities.amount !== undefined
                                ? { method: 'ai', matchedPattern: 'gemini-2.0-flash', rawSnippet: String(smartResult.entities.amount) }
                                : undefined,
                        },
                        intelligence: smartResult,
                        fileNature,
                    };
                }
            } catch (aiErr: any) {
                console.warn('[OCR] Gemini analysis failed, falling back to regex:', aiErr.message);
            }
        } else {
            console.warn('[OCR] No Gemini API key configured — using regex fallback only');
        }

        // ── Step 3: Regex/keyword fallback ──────────────────────────────────
        return { ...regexFallback(finalText, ocrConfidence), fileNature };

    } catch (error) {
        console.error('[OCR] Processing failed:', error);
        return { rawText: '', docType: 'unknown', confidence: 0, extractionTrace: {}, fileNature: 'unknown' };
    }
};

// ── Download + preprocess image → run Tesseract ──────────────────────────────

async function extractTextFromUrl(fileUrl: string, page: number): Promise<{ text: string; ocrConfidence: number; rawBuffer?: Buffer }> {
    const ocrUrl = transformUrlForOcr(fileUrl, page);
    const isPdf = fileUrl.toLowerCase().includes('.pdf');
    console.log(`[OCR] Downloading page ${page}: ${isPdf ? 'PDF→JPEG' : 'image'} | ${ocrUrl.slice(0, 90)}…`);

    const rawBuffer = await downloadToBuffer(ocrUrl);
    console.log(`[OCR] Downloaded ${rawBuffer.length} bytes`);

    // Preprocess with sharp: grayscale + increase contrast + normalise
    // This significantly improves Tesseract accuracy on low-contrast scans
    let imageBuffer: Buffer;
    try {
        imageBuffer = await sharp(rawBuffer)
            .grayscale()
            .normalise()
            .linear(1.2, -20)   // slight contrast boost
            .sharpen({ sigma: 1.5 })
            .toBuffer();
        console.log(`[OCR] Image preprocessed: ${imageBuffer.length} bytes`);
    } catch (sharpErr: any) {
        console.warn('[OCR] sharp preprocessing failed, using raw buffer:', sharpErr.message);
        imageBuffer = rawBuffer;
    }

    // Tesseract with PSM 6 (uniform block of text — best for structured forms/IDs)
    let text = '';
    let ocrConfidence = 0;
    try {
        const result = await Tesseract.recognize(imageBuffer, 'eng+hin', {
            // @ts-ignore — Tesseract.js accepts these params
            tessedit_pageseg_mode: '6',
        });
        text = result.data.text;
        ocrConfidence = result.data.confidence;
    } catch (tessErr: any) {
        console.warn('[OCR] eng+hin failed, retrying with eng only:', tessErr.message);
        const fallbackResult = await Tesseract.recognize(imageBuffer, 'eng', {
            // @ts-ignore
            tessedit_pageseg_mode: '6',
        });
        text = fallbackResult.data.text;
        ocrConfidence = fallbackResult.data.confidence;
    }

    return { text, ocrConfidence, rawBuffer };
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
                continue; // try next model
            }

            const docType = ALLOWED_DOC_TYPES.includes(parsed.doc_type) ? parsed.doc_type : 'Other';
            const category = DOC_CATEGORIES.includes(parsed.category) ? parsed.category : 'Other';
            const ent = parsed.entities || {};

            const suggested_events: Omit<ISuggestedEvent, 'accepted'>[] = (parsed.suggested_events || [])
                .map((e: any) => ({
                    title: String(e.title || ''),
                    date: parseGeminiDate(e.date),
                    event_type: ['expiry', 'renewal', 'payment', 'follow_up', 'milestone'].includes(e.event_type)
                        ? e.event_type : 'milestone',
                    reason: String(e.reason || ''),
                }))
                .filter((e: any) => e.date instanceof Date && !isNaN(e.date.getTime()) && e.title);

            let warrantyExpiry = parseGeminiDate(ent.warranty_expiry_date);
            if (!warrantyExpiry && ent.purchase_date) {
                const pDate = parseGeminiDate(ent.purchase_date);
                const wYears = typeof ent.warranty_years === 'number' ? ent.warranty_years : 1;
                if (pDate) warrantyExpiry = new Date(pDate.getFullYear() + wYears, pDate.getMonth(), pDate.getDate());
            }

            return {
                classification: {
                    doc_type: docType, category,
                    confidence: typeof parsed.confidence === 'number' ? Math.min(Math.max(parsed.confidence, 0), 1) : 0.5,
                    reasoning: String(parsed.reasoning || ''),
                },
                entities: {
                    person_name:            ent.person_name         || undefined,
                    id_number:              ent.id_number           || undefined,
                    policy_number:          ent.policy_number       || undefined,
                    registration_number:    ent.registration_number || undefined,
                    account_number:         ent.account_number      || undefined,
                    issued_by:              ent.issued_by           || undefined,
                    issue_date:             parseGeminiDate(ent.issue_date),
                    expiry_date:            parseGeminiDate(ent.expiry_date),
                    due_date:               parseGeminiDate(ent.due_date),
                    amount:                 typeof ent.amount === 'number' ? ent.amount : undefined,
                    institution:            ent.institution         || undefined,
                    address:                ent.address             || undefined,
                    dob:                    parseGeminiDate(ent.dob),
                    phone:                  ent.phone               || undefined,
                    purchase_date:          parseGeminiDate(ent.purchase_date),
                    warranty_expiry_date:   warrantyExpiry,
                    product_name:           ent.product_name        || undefined,
                    seller_name:            ent.seller_name         || ent.institution || undefined,
                    serial_number:          ent.serial_number       || undefined,
                    warranty_years:         typeof ent.warranty_years === 'number' ? ent.warranty_years : undefined,
                },
                tags: Array.isArray(parsed.tags)
                    ? parsed.tags.slice(0, 6).map((t: any) => String(t).toLowerCase().replace(/[^a-z0-9\-]/g, ''))
                    : [],
                importance: {
                    score: typeof parsed.importance?.score === 'number'
                        ? Math.min(Math.max(Math.round(parsed.importance.score), 1), 10) : 5,
                    criticality: ['low', 'medium', 'high', 'critical'].includes(parsed.importance?.criticality)
                        ? parsed.importance.criticality : 'medium',
                    lifecycle_stage: String(parsed.importance?.lifecycle_stage || 'active'),
                    renewal_window_days: typeof parsed.importance?.renewal_window_days === 'number'
                        ? parsed.importance.renewal_window_days : undefined,
                },
                suggested_events,
                ai_model: modelName,
                raw_ai_response: responseText,
            };
        } catch (err: any) {
            console.error(`[OCR] Gemini model=${modelName} FAILED: ${err.message}`);
            // try next model in the list
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
