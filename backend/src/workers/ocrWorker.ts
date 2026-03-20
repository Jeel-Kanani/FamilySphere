import { Worker, Job, UnrecoverableError } from 'bullmq';
import { redisConnectionOptions } from '../config/redis';
import { OcrJobData } from '../queues/ocrQueue';
import { processDocumentOcr } from '../services/ocrService';
import { EventGeneratorService } from '../services/eventGeneratorService';
import { NotificationService } from '../services/notificationService';
import DocumentIntelligence from '../models/DocumentIntelligence';
import { IntelligenceCoreService } from '../services/intelligence/IntelligenceCore';
import { FactSourceType } from '../models/IntelligenceFact';

/**
 * Phase 4 – OCR Background Worker
 *
 * Responsibilities:
 *  1. Pull OcrJobData from the "ocr" queue
 *  2. Run Tesseract OCR via processDocumentOcr()
 *  3. Patch the Document record with extracted metadata
 *  4. Trigger EventGeneratorService for timeline event creation
 *  5. On irreversible errors (doc not found) throw UnrecoverableError to skip retries
 *
 * Concurrency: 3 parallel OCR jobs (Tesseract is CPU-bound; tune to server cores)
 * Retry policy: 3 attempts, exponential back-off (5s/10s/20s), defined on the queue
 */
export const startOcrWorker = (): Worker<OcrJobData> => {
    // Dynamic import to avoid circular dependency at module-load time
    const worker = new Worker<OcrJobData>(
        'ocr',
        async (job: Job<OcrJobData>) => {
            const { documentId, fileUrl } = job.data;

            // Lazy-import models to avoid early Mongoose model registration issues
            const Document = (await import('../models/Document')).default;

            // Mark as processing so the client can show a spinner
            await Document.findByIdAndUpdate(documentId, { ocrStatus: 'processing' });

            await job.updateProgress(10);

            // ── Step 1: OCR ──────────────────────────────────────────────────
            let ocrResult;
            try {
                ocrResult = await processDocumentOcr(fileUrl);
            } catch (err: any) {
                // If Tesseract itself fails, mark document and escalate
                await Document.findByIdAndUpdate(documentId, { ocrStatus: 'failed' });
                throw new Error(`OCR extraction failed: ${err.message}`);
            }

            await job.updateProgress(70);

            // ── Step 2: Confidence-based 3-tier routing ───────────────────
            //
            //  Tier 1 AUTO   (≥ 0.75) — high confidence, events created silently
            //  Tier 2 ASSIST (0.40–0.74) — medium confidence, user reviews events
            //  Tier 3 UNKNOWN (< 0.40) — too uncertain, user manually categorises
            //
            const confidence = ocrResult.confidence;
            const tier: 'auto' | 'assist' | 'unknown' =
                confidence >= 0.75 ? 'auto' :
                    confidence >= 0.40 ? 'assist' : 'unknown';

            // For Tier 3, fall back to 'Other' so we never store garbage classifications
            const safeDocType = tier === 'unknown' ? 'Other' : (ocrResult.docType || 'Other');

            const updatedDoc = await Document.findByIdAndUpdate(
                documentId,
                {
                    rawText: ocrResult.rawText,
                    docType: ocrResult.docType || 'Other',
                    expiryDate: ocrResult.expiryDate,
                    dueDate: ocrResult.dueDate,
                    amount: ocrResult.amount,
                    ocrStatus: tier === 'auto' ? 'done' : 'analyzed',
                    ocrConfidence: confidence,
                },
                { new: true }
            );

            console.log(
                `[OCR Worker] Tier=${tier.toUpperCase()} | confidence=${(confidence * 100).toFixed(0)}% | ` +
                `nature=${ocrResult.fileNature ?? 'unknown'} | doc=${documentId} | docType=${safeDocType}`
            );

            // ── Step 2b: Save DocumentIntelligence (smart metadata) ──────────
            if (ocrResult.intelligence) {
                const intel = ocrResult.intelligence;

                // Helper to get first item from array safely
                const firstValue = (arr: any[]) => arr?.[0]?.value || null;
                const firstName = (arr: any[]) => arr?.[0]?.name || null;
                const firstAmount = (arr: any[]) => arr?.[0]?.value || null;
                const findDate = (tag: string) => intel.entities.important_dates.find(d => d.label?.toLowerCase().includes(tag))?.value;

                await DocumentIntelligence.findOneAndUpdate(
                    { documentId },
                    {
                        documentId,
                        familyId: updatedDoc?.familyId,
                        classification: {
                            document_type: intel.document_classification.document_type || 'Other',
                            category: intel.document_classification.category || 'Other',
                            subcategory: intel.document_classification.subcategory,
                            confidence: intel.document_classification.confidence,
                            reasoning: intel.document_classification.subcategory || ''
                        },
                        entities: {
                            // Flattened for legacy/quick access
                            person_name: firstName(intel.entities.people),
                            id_number: firstValue(intel.entities.id_numbers),
                            policy_number: intel.entities.id_numbers.find(id => id.type?.toLowerCase().includes('policy'))?.value,
                            registration_number: intel.entities.id_numbers.find(id => id.type?.toLowerCase().includes('reg'))?.value,
                            account_number: firstValue(intel.entities.financial_details.account_numbers),
                            issued_by: firstName(intel.entities.organizations),
                            issue_date: findDate('issue'),
                            expiry_date: findDate('expir'),
                            due_date: findDate('due'),
                            amount: firstAmount(intel.entities.financial_details.amounts),
                            institution: firstName(intel.entities.organizations),
                            address: firstValue(intel.entities.locations),
                            dob: findDate('birth'),
                            purchase_date: findDate('purchase'),
                            warranty_expiry_date: findDate('warranty'),
                            product_name: intel.document_classification.subcategory,
                            seller_name: firstName(intel.entities.organizations),
                            serial_number: intel.entities.id_numbers.find(id => id.type?.toLowerCase().includes('serial'))?.value,

                            // Rich Plural Arrays (Persisted for future AI Bot)
                            people: intel.entities.people,
                            organizations: intel.entities.organizations,
                            id_numbers: intel.entities.id_numbers,
                            locations: intel.entities.locations,
                            financial_details: intel.entities.financial_details,
                            important_dates: intel.entities.important_dates.map(d => ({
                                ...d,
                                value: d.value ? new Date(d.value) : null
                            }))
                        },
                        summary: intel.brief_summary,
                        tags: intel.tags,
                        importance: intel.importance,
                        suggested_events: intel.suggested_events.map(e => ({ ...e, accepted: false, reason: '' })),
                        needs_confirmation: tier !== 'auto',
                        confirmation_tier: tier,
                        ai_model: intel.ai_model,
                        analyzed_at: new Date(),
                        raw_ai_response: intel.raw_ai_response,
                    },
                    { upsert: true, new: true }
                );

                // 🔥 Unified Intelligence Platform: Create a Fact
                try {
                    await IntelligenceCoreService.processSource({
                        familyId: String(updatedDoc?.familyId),
                        userId: String(updatedDoc?.uploadedBy),
                        sourceType: FactSourceType.DOCUMENT,
                        sourceId: documentId,
                        rawText: ocrResult.rawText,
                        intelligence: intel,
                    });
                } catch (intelErr: any) {
                    console.error(`[OCR Worker] Failed to save unified fact for doc ${documentId}:`, intelErr.message);
                }

                console.log(
                    `[OCR Worker] Intelligence saved for doc ${documentId} | ` +
                    `type=${intel.document_classification.document_type} | ` +
                    `ai-confidence=${(intel.document_classification.confidence * 100).toFixed(0)}% | ` +
                    `tags=[${intel.tags.join(', ')}] | ` +
                    `suggested_events=${intel.suggested_events.length} | ` +
                    `entities: name=${firstName(intel.entities.people) ?? '-'} ` +
                    `expiry=${findDate('expir') ?? '-'} ` +
                    `id=${firstValue(intel.entities.id_numbers) ?? '-'}`
                );
            } else {
                console.warn(`[OCR Worker] No intelligence payload for doc ${documentId} — Gemini may be unconfigured or failed`);
            }

            if (!updatedDoc) {
                // Document was deleted while job was running — skip retries
                throw new UnrecoverableError(`Document ${documentId} no longer exists`);
            }

            await job.updateProgress(85);

            // ── Step 3: Generate timeline events ─────────────────────────────
            // ONLY Tier 1 (auto) gets events created immediately.
            // Tier 2 (assist): suggested_events stored with accepted=false, user confirms via UI.
            // Tier 3 (unknown): no events, user must manually categorise first.
            if (tier === 'auto') {
                try {
                    await EventGeneratorService.generateEventsFromDocument(updatedDoc);
                } catch (err: any) {
                    console.error(`[OCR Worker] Event generation failed for doc ${documentId}: ${err.message}`);
                }
            } else {
                console.log(
                    `[OCR Worker] Tier=${tier.toUpperCase()} — event creation deferred for doc ${documentId}. ` +
                    `User must ${tier === 'assist' ? 'confirm suggested events' : 'manually categorise document'}.`
                );
            }

            await job.updateProgress(90);

            // ── Step 4: Notify User ──────────────────────────────────────────
            try {
                await NotificationService.notifyOcrComplete(updatedDoc);
            } catch (err: any) {
                console.error(`[OCR Worker] Notification failed for doc ${documentId}: ${err.message}`);
            }

            await job.updateProgress(100);

            return {
                success: true,
                docType: ocrResult.docType,
                confidence: ocrResult.confidence,
            };
        },
        {
            connection: redisConnectionOptions,
            concurrency: process.env.OCR_CONCURRENCY ? parseInt(process.env.OCR_CONCURRENCY) : 3,
            // Stalled-job detection: if a worker crashes mid-job, reclaim after 30 s
            stalledInterval: 30_000,
            skipVersionCheck: true, // we use Redis 5.x intentionally on dev
        }
    );

    // ── Worker lifecycle logs ──────────────────────────────────────────────────
    worker.on('completed', (job) => {
        console.log(
            `[OCR Worker] ✓ Job ${job.id} completed | doc=${job.data.documentId} | type=${job.returnvalue?.docType}`
        );
    });

    worker.on('failed', (job, err) => {
        const attempts = job?.attemptsMade ?? '?';
        console.error(
            `[OCR Worker] ✗ Job ${job?.id} failed (attempt ${attempts}/3) | doc=${job?.data.documentId} | reason: ${err.message}`
        );
    });

    worker.on('stalled', (jobId) => {
        console.warn(`[OCR Worker] ⚠ Job ${jobId} stalled — will be requeued`);
    });

    worker.on('error', (err) => {
        console.error(`[OCR Worker] Worker error: ${err.message}`);
    });

    console.log('[OCR Worker] Started — concurrency: 3, queue: ocr');
    return worker;
};
