import Event, { EventType, EventStatus, EventSource } from '../models/Event';
import { IDocument } from '../models/Document';
import DocumentIntelligence from '../models/DocumentIntelligence';

/**
 * EventGeneratorService — Smart Timeline Engine
 *
 * GUARANTEE: Every document uploaded will ALWAYS generate at least 1 timeline event.
 *
 * Priority cascade:
 *  1. AI suggested_events (from Gemini analysis)
 *  2. Entity-based derived events (from extracted dates, purchase/warranty fields)
 *  3. Rule-based fallback (doc type pattern matching)
 *  4. ABSOLUTE FALLBACK — "Document Added" milestone using upload date (always fires)
 *
 * KEY RULES:
 *  - Past events (with EventStatus.EXPIRED) are created — shows document history on timeline
 *  - Events older than 3 years skipped unless milestone type
 *  - User-modified events are never overridden
 */
export class EventGeneratorService {

    static async generateEventsFromDocument(document: IDocument): Promise<void> {
        try {
            console.log(`🧠 [EventGen] Processing: "${document.title}" (${document._id})`);

            const intelligence = await DocumentIntelligence.findOne({ documentId: document._id });
            let totalCreated = 0;

            if (intelligence) {
                if (intelligence.suggested_events.length > 0) {
                    totalCreated += await this.createSmartEvents(document, intelligence);
                }
                // If smart events yielded nothing (all stale/skipped), try entity-based
                if (totalCreated === 0) {
                    console.log(`[EventGen] Smart path yielded 0 — deriving from entities`);
                    totalCreated += await this.createEventsFromEntities(document, intelligence);
                }
            } else {
                console.log(`[EventGen] No intelligence — using rule-based fallback`);
                totalCreated += await this.createRuleBasedEvents(document);
            }

            // ── ABSOLUTE FALLBACK: garanteed event so timeline never has a gap ─
            if (totalCreated === 0) {
                console.log(`[EventGen] All paths yielded 0 — firing absolute fallback milestone`);
                await this.createAbsoluteFallbackEvent(document);
            }

            console.log(`✅ [EventGen] Done for: "${document.title}" (${totalCreated} events total)`);
        } catch (error) {
            console.error('❌ [EventGen] Failed:', error);
        }
    }

    // ── Smart path: use AI suggested_events ───────────────────────────────────

    private static async createSmartEvents(
        document: IDocument,
        intelligence: NonNullable<Awaited<ReturnType<typeof DocumentIntelligence.findOne>>>
    ): Promise<number> {
        const now = new Date();
        const threeYearsAgo = new Date(now.getFullYear() - 3, now.getMonth(), now.getDate());
        const isLowConfidence = intelligence.classification.confidence < 0.70;
        let accepted = 0;
        let skipped = 0;

        for (const suggested of intelligence.suggested_events) {
            const eventDate = suggested.date instanceof Date ? suggested.date : new Date(suggested.date);

            if (isNaN(eventDate.getTime())) { skipped++; continue; }

            // Skip non-milestone events older than 3 years
            if (eventDate < threeYearsAgo && suggested.event_type !== 'milestone') {
                console.log(`[EventGen] Skipping "${suggested.title}" — older than 3 years`);
                skipped++;
                continue;
            }

            const status = eventDate < now ? EventStatus.EXPIRED : EventStatus.UPCOMING;
            const eventType = this.mapEventType(suggested.event_type);

            const existing = await Event.findOne({ relatedDocumentId: document._id, type: eventType });
            if (existing?.isUserModified) { skipped++; continue; }

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
                        status,
                        priority:    this.calcPriority(intelligence.importance.criticality, eventType),
                        needsReview: isLowConfidence,
                        snapshot: {
                            docTitle:            document.title,
                            amount:              intelligence.entities.amount,
                            currency:            'INR',
                            extractedExpiryDate: intelligence.entities.expiry_date,
                            extractionTrace: {
                                method:         'ai',
                                matchedPattern: intelligence.ai_model || 'gemini-2.0-flash',
                                rawSnippet:     intelligence.classification.reasoning,
                            },
                        },
                    },
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );

            suggested.accepted = true;
            accepted++;
            console.log(`[EventGen] ✓ Smart: "${suggested.title}" → ${eventDate.toISOString().slice(0, 10)} [${status}]`);
        }

        if (accepted > 0) {
            await DocumentIntelligence.findOneAndUpdate(
                { documentId: document._id },
                { $set: { suggested_events: intelligence.suggested_events } }
            );
        }

        console.log(`[EventGen] Smart: ${accepted}/${intelligence.suggested_events.length} created, ${skipped} skipped`);
        return accepted;
    }

    // ── Entity-based: derive events from all extracted fields ──────────────────

    private static async createEventsFromEntities(
        document: IDocument,
        intelligence: NonNullable<Awaited<ReturnType<typeof DocumentIntelligence.findOne>>>
    ): Promise<number> {
        const now = new Date();
        const ents = intelligence.entities;
        const renewalDays = intelligence.importance.renewal_window_days ?? 60;
        const docType = intelligence.classification.doc_type;
        let created = 0;

        const upsert = async (
            type: EventType,
            title: string,
            description: string,
            date: Date,
            priority: number
        ): Promise<void> => {
            if (!date || isNaN(date.getTime())) return;
            const existing = await Event.findOne({ relatedDocumentId: document._id, type });
            if (existing?.isUserModified) return;

            const status = date < now ? EventStatus.EXPIRED : EventStatus.UPCOMING;
            await Event.findOneAndUpdate(
                { relatedDocumentId: document._id, type, startDate: date },
                {
                    $setOnInsert: {
                        userId: document.uploadedBy, familyId: document.familyId,
                        source: EventSource.AI, relatedDocumentId: document._id, createdAt: new Date(),
                    },
                    $set: {
                        title, description, startDate: date, status, priority,
                        needsReview: intelligence.classification.confidence < 0.70,
                        snapshot: {
                            docTitle: document.title, amount: ents.amount, currency: 'INR',
                            extractedExpiryDate: ents.expiry_date ?? ents.warranty_expiry_date,
                        },
                    },
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );
            created++;
            console.log(`[EventGen] ✓ Entity: "${title}" → ${date.toISOString().slice(0, 10)} [${status}]`);
        };

        // ── Expiry & renewal ─────────────────────────────────────────────────
        if (ents.expiry_date) {
            await upsert(EventType.EXPIRY, `${docType} Expires`, `${document.title} — expiry date`, ents.expiry_date, 4);
            const renewalDate = new Date(ents.expiry_date.getTime() - renewalDays * 86400000);
            if (renewalDate > now) {
                await upsert(EventType.TASK, `Renew ${docType}`, `Start renewal — expires ${ents.expiry_date.toISOString().slice(0, 10)}`, renewalDate, 3);
            }
        }

        // ── Purchase receipt / invoice / shopping ────────────────────────────
        if (ents.purchase_date) {
            const item = ents.product_name || document.title;
            const seller = ents.seller_name ? ` from ${ents.seller_name}` : '';
            const amtStr = ents.amount ? ` ₹${ents.amount}` : '';
            await upsert(EventType.MILESTONE, `Purchased ${item}`, `Bought ${item}${seller}${amtStr}`, ents.purchase_date, 2);
        }

        // ── Warranty expiry ──────────────────────────────────────────────────
        if (ents.warranty_expiry_date) {
            const item = ents.product_name || document.title;
            await upsert(EventType.EXPIRY, `${item} Warranty Expires`, `Get service before warranty ends`, ents.warranty_expiry_date, 3);
            // Warranty reminder 30 days before
            const warnDate = new Date(ents.warranty_expiry_date.getTime() - 30 * 86400000);
            if (warnDate > now) {
                await upsert(EventType.TASK, `${item} Warranty Ending Soon`, `Check product condition — warranty expires soon`, warnDate, 3);
            }
        }

        // ── Due date (bills, EMI, fees) ──────────────────────────────────────
        if (ents.due_date) {
            const amtStr = ents.amount ? ` ₹${ents.amount}` : '';
            await upsert(EventType.BILL_DUE, `Pay ${document.title}`, `Payment due${amtStr}`, ents.due_date, 4);
        }

        // ── Issue / creation date as milestone ───────────────────────────────
        if (ents.issue_date) {
            await upsert(EventType.MILESTONE, `${docType} Issued`, `${document.title} issued / created`, ents.issue_date, 2);
        }

        // ── Salary credited ──────────────────────────────────────────────────
        const isSalaryDoc = ['Salary Slip'].includes(docType);
        if (isSalaryDoc && (ents.issue_date || document.createdAt)) {
            const salaryDate = ents.issue_date ?? document.createdAt;
            if (salaryDate) {
                const amtStr = ents.amount ? ` ₹${ents.amount}` : '';
                await upsert(EventType.MILESTONE, `Salary Credited${amtStr}`, `Salary for ${salaryDate.toLocaleString('default', { month: 'long', year: 'numeric' })}`, salaryDate, 2);
            }
        }

        // ── Document upload event (covers everything else) ───────────────────
        if (created === 0) {
            const uploadDate = document.createdAt ?? new Date();
            await upsert(EventType.MILESTONE, `${document.title} Added`, `Document filed to family vault`, uploadDate, 1);
        }

        console.log(`[EventGen] Entity-based: ${created} event(s) created for "${document.title}"`);
        return created;
    }

    // ── Rule-based fallback: when no DocumentIntelligence at all ──────────────

    private static async createRuleBasedEvents(document: IDocument): Promise<number> {
        const docType  = (document.docType || '').toLowerCase();
        const now      = new Date();
        let created    = 0;

        const save = async (
            type: EventType, title: string, description: string,
            date: Date, priority: number
        ) => {
            if (!date || isNaN(date.getTime())) return;
            const existing = await Event.findOne({ relatedDocumentId: document._id, type });
            if (existing?.isUserModified) return;
            const status = date < now ? EventStatus.EXPIRED : EventStatus.UPCOMING;
            await Event.findOneAndUpdate(
                { relatedDocumentId: document._id, type, startDate: date },
                {
                    $setOnInsert: { userId: document.uploadedBy, familyId: document.familyId, source: EventSource.AI, relatedDocumentId: document._id, createdAt: new Date() },
                    $set: { title, description, startDate: date, status, priority, needsReview: false, snapshot: { docTitle: document.title, amount: document.amount, currency: 'INR', extractedExpiryDate: document.expiryDate } },
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );
            created++;
            console.log(`[EventGen] ✓ Rule: "${title}" → ${date.toISOString().slice(0, 10)} [${status}]`);
        };

        // Bill with due date
        if (document.dueDate) {
            await save(EventType.BILL_DUE, `Pay ${document.title}`, `Payment due ₹${document.amount ?? '---'}`, document.dueDate, 4);
        }

        // Expiry date (any type)
        if (document.expiryDate) {
            await save(EventType.EXPIRY, `${document.title} Expiry`, `Renew/act before expiry`, document.expiryDate, 4);
        }

        // Receipt / purchase keywords in title
        const isReceipt = /receipt|invoice|bill|order|purchased?|bought|payment/i.test(document.title);
        if (isReceipt) {
            const purchaseDate = document.createdAt ?? new Date();
            await save(EventType.MILESTONE, `${document.title}`, `Purchase recorded`, purchaseDate, 2);
        }

        // Upload milestone fallback
        if (created === 0) {
            const uploadDate = document.createdAt ?? new Date();
            await save(EventType.MILESTONE, `${document.title} Added`, `Document added to vault`, uploadDate, 1);
        }

        return created;
    }

    // ── Absolute guarantee fallback ───────────────────────────────────────────
    // This fires ONLY when every other path produces 0 events.
    // Ensures the timeline ALWAYS has an entry for every document.

    private static async createAbsoluteFallbackEvent(document: IDocument): Promise<void> {
        const date = document.createdAt ?? new Date();
        const existing = await Event.findOne({ relatedDocumentId: document._id, type: EventType.MILESTONE });
        if (existing) return; // already has one

        await Event.findOneAndUpdate(
            { relatedDocumentId: document._id, type: EventType.MILESTONE, startDate: date },
            {
                $setOnInsert: {
                    userId: document.uploadedBy, familyId: document.familyId,
                    source: EventSource.AI, relatedDocumentId: document._id, createdAt: new Date(),
                },
                $set: {
                    title:       `${document.title} Added`,
                    description: `Document saved to family vault`,
                    startDate:   date,
                    status:      EventStatus.COMPLETED,
                    priority:    1,
                    needsReview: false,
                    snapshot:    { docTitle: document.title, currency: 'INR' },
                },
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );
        console.log(`[EventGen] ✓ Absolute fallback milestone for "${document.title}"`);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static mapEventType(eventType: string): EventType {
        switch (eventType) {
            case 'expiry':    return EventType.EXPIRY;
            case 'payment':   return EventType.BILL_DUE;
            case 'renewal':   return EventType.TASK;
            case 'follow_up': return EventType.TASK;
            case 'milestone': return EventType.MILESTONE;
            default:          return EventType.MILESTONE;
        }
    }

    private static calcPriority(criticality: string, eventType: EventType): number {
        const base: Record<string, number> = { low: 1, medium: 2, high: 3, critical: 4 };
        const boost = (eventType === EventType.EXPIRY || eventType === EventType.BILL_DUE) ? 1 : 0;
        return Math.min((base[criticality] ?? 2) + boost, 5);
    }
}
