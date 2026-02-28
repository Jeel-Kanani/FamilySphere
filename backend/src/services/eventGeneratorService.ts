import Event, { EventType, EventStatus, EventSource } from '../models/Event';
import { IDocument } from '../models/Document';
import { processDocumentOcr, OcrResult } from './ocrService';

/**
 * EventGeneratorService
 * The "Brain" that takes a document and populates the Personal Time Intelligence System.
 */
export class EventGeneratorService {
    /**
     * Entry point after document upload
     */
    static async generateEventsFromDocument(document: IDocument): Promise<void> {
        try {
            console.log(`🧠 Processing Document: ${document.title} (${document._id})`);

            // 1. Run OCR intelligence
            const ocrResult = await processDocumentOcr(document.fileUrl);

            // 2. Update Document with Intelligence data
            document.rawText = ocrResult.rawText;
            document.docType = ocrResult.docType;
            if (ocrResult.expiryDate) document.expiryDate = ocrResult.expiryDate;
            if (ocrResult.dueDate) document.dueDate = ocrResult.dueDate;
            if (ocrResult.amount) document.amount = ocrResult.amount;

            await document.save();

            // 3. Threshold Logic: Auto-Accept vs Review
            const isConfidenceLow = ocrResult.confidence < 0.65;

            // 4. Create Timeline Event based on classification
            await this.createEvent(document, ocrResult, isConfidenceLow);

            console.log(`✅ Event Generation Complete for: ${document.title} (Confidence: ${ocrResult.confidence})`);
        } catch (error) {
            console.error('❌ Event Generation Failed:', error);
        }
    }

    private static async createEvent(document: IDocument, ocr: OcrResult, isConfidenceLow: boolean): Promise<void> {
        let eventType = EventType.DOCUMENT_UPLOAD;
        let eventDate = document.createdAt;
        let title = `Uploaded: ${document.title}`;
        let description = isConfidenceLow
            ? `⚠️ Review needed: Detected ${ocr.docType.replace('_', ' ')}`
            : `Automated upload event for ${ocr.docType.replace('_', ' ')}`;

        // Intelligence: Shift type and date based on OCR
        if (ocr.docType === 'electricity_bill' || ocr.docType === 'water_bill') {
            eventType = EventType.BILL_DUE;
            eventDate = ocr.dueDate || ocr.expiryDate || new Date();
            title = `Pay ${document.docType.replace('_', ' ')}`;
            description = `Pending payment of ₹${ocr.amount || '---'}`;
        } else if (ocr.expiryDate) {
            eventType = EventType.EXPIRY;
            eventDate = ocr.expiryDate;
            title = `${document.title} Expiry`;
            description = `Renew your ${ocr.docType.replace('_', ' ')} before it expiries.`;
        }

        // ─── SYSTEM INTEGRITY GUARD ───────────────────────────────────────────
        // If the user has manually corrected this event, OCR must NOT override it.
        const existingEvent = await Event.findOne({
            relatedDocumentId: document._id,
            type: eventType,
            startDate: eventDate
        });

        if (existingEvent?.isUserModified) {
            console.log(`🔒 Skipping OCR override for event ${existingEvent._id} — marked isUserModified`);
            return;
        }

        // ─── DUPLICATE PREVENTION ─────────────────────────────────────────────
        // Dedup key: relatedDocumentId + type + startDate
        // This prevents timeline pollution if OCR runs twice for the same document.
        await Event.findOneAndUpdate(
            {
                relatedDocumentId: document._id,
                type: eventType,
                startDate: eventDate
            },
            {
                $setOnInsert: {
                    // These fields only set on first insert, not on re-runs
                    userId: document.uploadedBy,
                    familyId: document.familyId,
                    source: EventSource.AI,
                    relatedDocumentId: document._id,
                    createdAt: new Date()
                },
                $set: {
                    title,
                    description,
                    status: EventStatus.UPCOMING,
                    priority: (eventType === EventType.EXPIRY || eventType === EventType.BILL_DUE)
                        ? (isConfidenceLow ? 3 : 4)
                        : 2,
                    needsReview: isConfidenceLow,

                    // ─── IMMUTABLE SNAPSHOT ───────────────────────────────────
                    // Stores the OCR state at time of extraction.
                    // Remains meaningful even if the document is later deleted.
                    snapshot: {
                        docTitle: document.title,
                        amount: ocr.amount,
                        currency: 'INR',
                        extractedExpiryDate: ocr.expiryDate,  // raw OCR value before user edits
                        extractionTrace: ocr.extractionTrace.date ?? ocr.extractionTrace.docType
                    }
                }
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );
    }
}
