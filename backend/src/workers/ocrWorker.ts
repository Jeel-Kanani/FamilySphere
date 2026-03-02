import { Worker, Job, UnrecoverableError } from 'bullmq';
import { redisConnectionOptions } from '../config/redis';
import { OcrJobData } from '../queues/ocrQueue';
import { processDocumentOcr } from '../services/ocrService';
import { EventGeneratorService } from '../services/eventGeneratorService';
import { NotificationService } from '../services/notificationService';
import DocumentIntelligence from '../models/DocumentIntelligence';

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
            const safeDocType = tier === 'unknown' ? 'Other' : ocrResult.docType;

            const updatedDoc = await Document.findByIdAndUpdate(
                documentId,
                {
                    rawText: ocrResult.rawText,
                    docType: safeDocType,
                    expiryDate: tier !== 'unknown' ? ocrResult.expiryDate : undefined,
                    dueDate:    tier !== 'unknown' ? ocrResult.dueDate    : undefined,
                    amount:     tier !== 'unknown' ? ocrResult.amount     : undefined,
                    ocrStatus:  tier === 'auto' ? 'done' : 'needs_confirmation',
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
                await DocumentIntelligence.findOneAndUpdate(
                    { documentId },
                    {
                        documentId,
                        familyId: updatedDoc?.familyId,
                        classification: tier === 'unknown'
                            ? { ...intel.classification, doc_type: 'Other', category: 'Other', confidence: intel.classification.confidence }
                            : intel.classification,
                        entities: {
                            person_name:         intel.entities.person_name,
                            id_number:           intel.entities.id_number,
                            policy_number:       intel.entities.policy_number,
                            registration_number: intel.entities.registration_number,
                            account_number:      intel.entities.account_number,
                            issued_by:           intel.entities.issued_by,
                            issue_date:          intel.entities.issue_date,
                            expiry_date:         intel.entities.expiry_date,
                            due_date:            intel.entities.due_date,
                            amount:              intel.entities.amount,
                            institution:         intel.entities.institution,
                            address:             intel.entities.address,
                            dob:                 intel.entities.dob,
                            phone:               intel.entities.phone,
                            purchase_date:       intel.entities.purchase_date,
                            warranty_expiry_date:intel.entities.warranty_expiry_date,
                            product_name:        intel.entities.product_name,
                            seller_name:         intel.entities.seller_name,
                            serial_number:       intel.entities.serial_number,
                            warranty_years:      intel.entities.warranty_years,
                        },
                        tags: intel.tags,
                        importance: intel.importance,
                        suggested_events: intel.suggested_events.map(e => ({ ...e, accepted: false })),
                        needs_confirmation: tier !== 'auto',
                        confirmation_tier: tier,
                        ai_model: intel.ai_model,
                        analyzed_at: new Date(),
                        raw_ai_response: intel.raw_ai_response,
                    },
                    { upsert: true, new: true }
                );
                console.log(
                    `[OCR Worker] Intelligence saved for doc ${documentId} | ` +
                    `type=${intel.classification.doc_type} | ` +
                    `ai-confidence=${(intel.classification.confidence * 100).toFixed(0)}% | ` +
                    `tags=[${intel.tags.join(', ')}] | ` +
                    `suggested_events=${intel.suggested_events.length} | ` +
                    `entities: name=${intel.entities.person_name ?? '-'} ` +
                    `expiry=${intel.entities.expiry_date?.toISOString?.().slice(0, 10) ?? '-'} ` +
                    `id=${intel.entities.id_number ?? '-'}`
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
            concurrency: 3,
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
