import { Queue, QueueEvents } from 'bullmq';
import { redisConnectionOptions } from '../config/redis';

// ── Job payload ────────────────────────────────────────────────────────────────
export interface OcrJobData {
    documentId: string;   // MongoDB _id of the Document
    fileUrl: string;      // Cloudinary / remote URL for Tesseract
    familyId: string;     // For scoping downstream event generation
}

// ── Queue ─────────────────────────────────────────────────────────────────────
export const ocrQueue = new Queue<OcrJobData>('ocr', {
    connection: redisConnectionOptions,
    skipVersionCheck: true, // we intentionally use Redis 5.x on dev
    defaultJobOptions: {
        attempts: 3,
        backoff: {
            type: 'exponential',
            delay: 5_000,      // 5 s → 10 s → 20 s
        },
        removeOnComplete: { count: 200 },   // keep last 200 for audit
        removeOnFail:     { count: 100 },   // keep last 100 for debugging
    },
});

// ── Queue-level events (optional telemetry) ───────────────────────────────────
export const ocrQueueEvents = new QueueEvents('ocr', {
    connection: redisConnectionOptions,
    skipVersionCheck: true,
});

ocrQueueEvents.on('waiting',   ({ jobId }) => console.log(`[OCR Queue] Job ${jobId} waiting`));
ocrQueueEvents.on('active',    ({ jobId }) => console.log(`[OCR Queue] Job ${jobId} started`));
ocrQueueEvents.on('completed', ({ jobId }) => console.log(`[OCR Queue] Job ${jobId} done`));
ocrQueueEvents.on('failed',    ({ jobId, failedReason }) =>
    console.error(`[OCR Queue] Job ${jobId} failed: ${failedReason}`)
);
