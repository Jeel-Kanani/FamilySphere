import Event, { EventType, EventStatus, EventSource } from '../models/Event';
import { IDocument } from '../models/Document';
import DocumentIntelligence from '../models/DocumentIntelligence';

/**
 * EventGeneratorService — Smart Timeline Engine
 *
 * Uses AI-suggested events from DocumentIntelligence when available.
 * Falls back to rule-based logic if intelligence is missing.
 *
 * Rules for accepting a suggested event:
 *  1. Must have a valid date
 *  2. Past dates skipped unless event_type is 'milestone'
 *  3. No duplicate (same doc + same event_type + same date)
 *  4. User-modified events are never overridden
 */
export class EventGeneratorService {

    static async generateEventsFromDocument(document: IDocument): Promise<void> {
        try {
            console.log(`🧠 [EventGen] Processing: "${document.title}" (${document._id})`);

            // Look up DocumentIntelligence saved by the OCR worker
            const intelligence = await DocumentIntelligence.findOne({ documentId: document._id });

            if (intelligence && intelligence.suggested_events.length > 0) {
                await this.createSmartEvents(document, intelligence);
            } else {
                await this.createRuleBasedEvents(document);
            }

            console.log(`✅ [EventGen] Done for: "${document.title}"`);
        } catch (error) {
            console.error('❌ [EventGen] Failed:', error);
        }
    }

    // ── Smart path: use AI suggested_events ───────────────────────────────────

    private static async createSmartEvents(
        document: IDocument,
        intelligence: NonNullable<Awaited<ReturnType<typeof DocumentIntelligence.findOne>>>
    ): Promise<void> {
        const now = new Date();
        const isLowConfidence = intelligence.classification.confidence < 0.70;
        let accepted = 0;

        for (const suggested of intelligence.suggested_events) {
            const eventDate = suggested.date instanceof Date ? suggested.date : new Date(suggested.date);

            // Rule 1: must be a valid date
            if (isNaN(eventDate.getTime())) continue;

            // Rule 2: skip past dates except milestones
            if (eventDate < now && suggested.event_type !== 'milestone') {
                console.log(`[EventGen] Skipping "${suggested.title}" — date in past`);
                continue;
            }

            const eventType = this.mapEventType(suggested.event_type);

            // Rule 3: don't override user-modified events
            const existing = await Event.findOne({ relatedDocumentId: document._id, type: eventType });
            if (existing?.isUserModified) continue;

            // Rule 4: upsert to prevent duplicates
            await Event.findOneAndUpdate(
                { relatedDocumentId: document._id, type: eventType, startDate: eventDate },
                {
                    $setOnInsert: {
                        userId:            document.uploadedBy,
                        familyId:          document.familyId,
                        source:            EventSource.AI,
                        relatedDocumentId: document._id,
                        createdAt:         new Date(),
                    },
                    $set: {
                        title:       suggested.title,
                        description: suggested.reason,
                        startDate:   eventDate,
                        status:      EventStatus.UPCOMING,
                        priority:    this.calcPriority(intelligence.importance.criticality, eventType),
                        needsReview: isLowConfidence,
                        snapshot: {
                            docTitle:            document.title,
                            amount:              intelligence.entities.amount,
                            currency:            'INR',
                            extractedExpiryDate: intelligence.entities.expiry_date,
                            extractionTrace:     {
                                method: 'ai',
                                matchedPattern: 'gemini-1.5-flash',
                                rawSnippet: intelligence.classification.reasoning,
                            },
                        },
                    },
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );

            suggested.accepted = true;
            accepted++;
            console.log(`[EventGen] ✓ Event: "${suggested.title}" → ${eventDate.toISOString().slice(0, 10)}`);
        }

        if (accepted > 0) {
            await DocumentIntelligence.findOneAndUpdate(
                { documentId: document._id },
                { $set: { suggested_events: intelligence.suggested_events } }
            );
        }

        console.log(`[EventGen] ${accepted}/${intelligence.suggested_events.length} events created for "${document.title}"`);
    }

    // ── Fallback path: rule-based when AI unavailable ─────────────────────────

    private static async createRuleBasedEvents(document: IDocument): Promise<void> {
        const docType  = (document.docType || '').toLowerCase();
        const now      = new Date();
        let eventType  = EventType.DOCUMENT_UPLOAD;
        let eventDate  = document.createdAt;
        let title      = `Uploaded: ${document.title}`;
        let description = 'Document uploaded to vault';

        if ((docType.includes('bill')) && document.dueDate) {
            eventType   = EventType.BILL_DUE;
            eventDate   = document.dueDate;
            title       = `Pay ${docType.replace(/_/g, ' ')}`;
            description = `Pending payment of ₹${document.amount || '---'}`;
        } else if (document.expiryDate && document.expiryDate > now) {
            eventType   = EventType.EXPIRY;
            eventDate   = document.expiryDate;
            title       = `${document.title} Expiry`;
            description = `Renew before it expires.`;
        } else {
            return; // no meaningful event
        }

        const existing = await Event.findOne({ relatedDocumentId: document._id, type: eventType });
        if (existing?.isUserModified) return;

        await Event.findOneAndUpdate(
            { relatedDocumentId: document._id, type: eventType, startDate: eventDate },
            {
                $setOnInsert: {
                    userId: document.uploadedBy, familyId: document.familyId,
                    source: EventSource.AI, relatedDocumentId: document._id, createdAt: new Date(),
                },
                $set: {
                    title, description, startDate: eventDate,
                    status: EventStatus.UPCOMING, priority: 3, needsReview: false,
                    snapshot: { docTitle: document.title, amount: document.amount, currency: 'INR', extractedExpiryDate: document.expiryDate },
                },
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static mapEventType(eventType: string): EventType {
        switch (eventType) {
            case 'expiry':    return EventType.EXPIRY;
            case 'payment':   return EventType.BILL_DUE;
            case 'renewal':   return EventType.TASK;
            case 'follow_up': return EventType.TASK;
            case 'milestone': return EventType.MILESTONE;
            default:          return EventType.TASK;
        }
    }

    private static calcPriority(criticality: string, eventType: EventType): number {
        const base: Record<string, number> = { low: 1, medium: 2, high: 3, critical: 4 };
        const boost = (eventType === EventType.EXPIRY || eventType === EventType.BILL_DUE) ? 1 : 0;
        return Math.min((base[criticality] ?? 2) + boost, 5);
    }
}
