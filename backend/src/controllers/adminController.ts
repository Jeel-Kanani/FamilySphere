import { Request, Response } from 'express';
import mongoose from 'mongoose';
import Document from '../models/Document';
import DocumentIntelligence from '../models/DocumentIntelligence';
import Event from '../models/Event';
import { ocrQueue } from '../queues/ocrQueue';
import { appState } from '../config/appState';

// ─── Pipeline stage labels ────────────────────────────────────────────────────
// "pending"             → uploaded, waiting for BullMQ job
// "processing"          → BullMQ job running (OCR in progress)
// "ocr_done_no_ai"      → OCR finished, Gemini prompt never ran / failed silently
// "needs_confirmation"  → AI done, confidence < 70% — user must confirm doc type
// "ai_done"             → AI done, confidence ≥ 70%, fully processed
// "events_created"      → same as ai_done + at least one Event row exists
// "failed"              → ocrStatus: 'failed'

function pipelineStage(
    ocrStatus: string,
    hasIntel: boolean,
    intelNeedsConfirmation: boolean,
    eventCount: number,
): string {
    if (ocrStatus === 'failed') return 'failed';
    if (ocrStatus === 'processing') return 'processing';
    if (ocrStatus === 'pending') return 'pending';
    // ocrStatus is 'done' or 'needs_confirmation'
    if (!hasIntel) return 'ocr_done_no_ai';
    if (intelNeedsConfirmation) return 'needs_confirmation';
    if (eventCount > 0) return 'events_created';
    return 'ai_done';
}

// ─── GET /api/admin/engine-dashboard ─────────────────────────────────────────
export const getEngineDashboard = async (req: Request, res: Response) => {
    try {
        // 1. Aggregate docs with intelligence and event counts
        const docs = await Document.aggregate([
            { $match: { deleted: false } },

            // Join intelligence
            {
                $lookup: {
                    from: 'documentintelligences',
                    localField: '_id',
                    foreignField: 'documentId',
                    as: 'intel',
                },
            },

            // Join events (just a count)
            {
                $lookup: {
                    from: 'events',
                    localField: '_id',
                    foreignField: 'relatedDocumentId',
                    as: 'events',
                },
            },

            {
                $project: {
                    _id: 1,
                    title: 1,
                    category: 1,
                    folder: 1,
                    familyId: 1,
                    ocrStatus: 1,
                    ocrConfidence: 1,
                    docType: 1,
                    fileType: 1,
                    fileSize: 1,
                    createdAt: 1,
                    updatedAt: 1,
                    // Raw OCR text length as a proxy for "how much text was extracted"
                    rawTextLength: { $strLenCP: { $ifNull: ['$rawText', ''] } },
                    // Intelligence summary
                    hasIntel: { $gt: [{ $size: '$intel' }, 0] },
                    intel: { $arrayElemAt: ['$intel', 0] },
                    eventCount: { $size: '$events' },
                },
            },

            { $sort: { createdAt: -1 } },
        ]);

        // 2. Compute pipeline stage per doc and build response
        const enriched = docs.map((d: any) => {
            const stage = pipelineStage(
                d.ocrStatus,
                d.hasIntel,
                d.intel?.needs_confirmation ?? false,
                d.eventCount,
            );

            return {
                id: d._id.toString(),
                title: d.title,
                category: d.category,
                folder: d.folder,
                familyId: d.familyId?.toString(),
                fileType: d.fileType,
                fileSize: d.fileSize,
                ocrStatus: d.ocrStatus,
                rawTextLength: d.rawTextLength,
                stage,
                createdAt: d.createdAt,
                updatedAt: d.updatedAt,
                // AI metadata (null if not available)
                ai: d.hasIntel
                    ? {
                          docType: d.intel.classification?.doc_type ?? null,
                          category: d.intel.classification?.category ?? null,
                          confidence: d.intel.classification?.confidence ?? 0,
                          needsConfirmation: d.intel.needs_confirmation ?? false,
                          tags: d.intel.tags ?? [],
                          importanceScore: d.intel.importance?.score ?? null,
                          criticality: d.intel.importance?.criticality ?? null,
                          lifecycleStage: d.intel.importance?.lifecycle_stage ?? null,
                          suggestedEventsCount: (d.intel.suggested_events ?? []).length,
                          entities: d.intel.entities ?? {},
                          aiModel: d.intel.ai_model ?? null,
                          analyzedAt: d.intel.analyzed_at ?? null,
                      }
                    : null,
                eventCount: d.eventCount,
            };
        });

        // 3. Summary stats
        const stageCounts: Record<string, number> = {
            pending: 0,
            processing: 0,
            ocr_done_no_ai: 0,
            needs_confirmation: 0,
            ai_done: 0,
            events_created: 0,
            failed: 0,
        };
        for (const d of enriched) {
            if (stageCounts[d.stage] !== undefined) {
                stageCounts[d.stage]++;
            }
        }

        // 4. BullMQ queue stats (best-effort)
        let queueStats: Record<string, number> | null = null;
        if (appState.ocrQueueEnabled) {
            try {
                queueStats = await ocrQueue.getJobCounts(
                    'waiting', 'active', 'completed', 'failed', 'delayed',
                );
            } catch {
                queueStats = null;
            }
        }

        // 5. Failed docs detail for deep-dive
        const failedDocs = enriched.filter(d => d.stage === 'failed');

        res.json({
            summary: {
                total: enriched.length,
                stages: stageCounts,
                queueEnabled: appState.ocrQueueEnabled,
                queue: queueStats,
            },
            documents: enriched,
            failedDocuments: failedDocs,
        });
    } catch (err: any) {
        console.error('[AdminController] engine-dashboard error:', err);
        res.status(500).json({ error: 'Failed to fetch engine dashboard', details: err.message });
    }
};

// ─── POST /api/admin/requeue-stuck ───────────────────────────────────────────
export const adminRequeueStuck = async (req: Request, res: Response) => {
    try {
        if (!appState.ocrQueueEnabled) {
            return res.status(503).json({ error: 'OCR queue is not enabled (Redis unavailable)' });
        }

        const stuck = await Document.find({
            deleted: false,
            ocrStatus: { $in: ['pending', 'processing', 'failed'] },
        }).lean();

        if (stuck.length === 0) {
            return res.json({ message: 'No stuck documents found.', requeued: 0 });
        }

        let requeued = 0;
        for (const doc of stuck) {
            try {
                await ocrQueue.add(
                    'ocr',
                    {
                        documentId: doc._id.toString(),
                        fileUrl: doc.fileUrl,
                        familyId: doc.familyId.toString(),
                    },
                    { removeOnComplete: true, removeOnFail: false },
                );
                await Document.findByIdAndUpdate(doc._id, { ocrStatus: 'pending' });
                requeued++;
            } catch {
                // skip individual failures
            }
        }

        res.json({
            message: `Re-queued ${requeued} of ${stuck.length} stuck documents.`,
            requeued,
            total: stuck.length,
        });
    } catch (err: any) {
        res.status(500).json({ error: 'Requeue failed', details: err.message });
    }
};

// ─── GET /api/admin/doc/:id/full ─────────────────────────────────────────────
// Deep-dive for a single document — all info in one call
export const getDocumentFullDetail = async (req: Request, res: Response) => {
    try {
        const id = req.params.id as string;
        if (!mongoose.Types.ObjectId.isValid(id)) {
            return res.status(400).json({ error: 'Invalid document id' });
        }

        const oid = new mongoose.Types.ObjectId(id);
        const [doc, intel, events] = await Promise.all([
            Document.findById(oid).lean(),
            DocumentIntelligence.findOne({ documentId: oid }).lean(),
            Event.find({ relatedDocumentId: oid }).lean(),
        ]);

        if (!doc) return res.status(404).json({ error: 'Document not found' });

        res.json({ doc, intel, events });
    } catch (err: any) {
        res.status(500).json({ error: 'Failed to fetch document detail', details: err.message });
    }
};
