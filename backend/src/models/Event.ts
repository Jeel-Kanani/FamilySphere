import mongoose from 'mongoose';

export enum EventType {
    EXPIRY = 'expiry',
    BILL_DUE = 'bill_due',
    BILL_PAID = 'bill_paid',
    BIRTHDAY = 'birthday',
    DOCUMENT_UPLOAD = 'document_upload',
    TASK = 'task',
    MILESTONE = 'milestone'
}

export enum EventStatus {
    UPCOMING = 'upcoming',
    COMPLETED = 'completed',
    EXPIRED = 'expired',
    CANCELLED = 'cancelled'
}

export enum EventSource {
    AI = 'ai',
    SYSTEM = 'system',
    MANUAL = 'manual'
}

export interface IEvent extends mongoose.Document {
    userId: mongoose.Types.ObjectId;
    familyId: mongoose.Types.ObjectId;
    type: EventType;
    title: string;
    description?: string;
    startDate: Date;
    endDate?: Date;
    status: EventStatus;
    source: EventSource;
    priority: number; // 1: Low, 5: Critical
    relatedDocumentId?: mongoose.Types.ObjectId;

    // OCR review & trust flags
    needsReview?: boolean;             // AI confidence was low — user should verify
    reviewAutoExpiredAt?: Date;        // Set when auto-dismissed after 30-day inactivity
    isUserModified?: boolean;          // User manually edited this event — OCR must not override

    // Immutable snapshot — remains valid even if original document is deleted
    snapshot?: {
        docTitle?: string;
        amount?: number;
        currency?: string;
        documentNumber?: string;
        extractedExpiryDate?: Date;    // Raw OCR-extracted date before any user edit
        extractionTrace?: {            // Forensic record: how each field was extracted
            method: 'regex' | 'keyword' | 'ai';
            matchedPattern: string;
            rawSnippet: string;
        };
    };

    createdAt: Date;
    updatedAt: Date;
}

const eventSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    familyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Family', required: true },
    type: {
        type: String,
        enum: Object.values(EventType),
        default: EventType.TASK
    },
    title: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
    startDate: { type: Date, required: true },
    endDate: { type: Date },
    status: {
        type: String,
        enum: Object.values(EventStatus),
        default: EventStatus.UPCOMING
    },
    source: {
        type: String,
        enum: Object.values(EventSource),
        default: EventSource.MANUAL
    },
    priority: { type: Number, default: 3, min: 1, max: 5 },
    relatedDocumentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Document' },

    // OCR review & trust flags
    needsReview: { type: Boolean, default: false },
    reviewAutoExpiredAt: { type: Date },
    isUserModified: { type: Boolean, default: false },

    // Immutable snapshot — survives document deletion
    snapshot: {
        docTitle: String,
        amount: Number,
        currency: String,
        documentNumber: String,
        extractedExpiryDate: Date,
        extractionTrace: {
            method: { type: String, enum: ['regex', 'keyword', 'ai'] },
            matchedPattern: String,
            rawSnippet: String
        }
    }
}, { timestamps: true });

// CRITICAL INDEXES for Infinite Scroll and Performance
// Fast fetch by family and date
eventSchema.index({ familyId: 1, startDate: -1 });

// Fast fetch for specific status (e.g., "Active Expiries")
eventSchema.index({ userId: 1, status: 1, startDate: 1 });

// Text search for the timeline
eventSchema.index({ title: 'text', description: 'text' });

// DEDUPLICATION INDEX: Prevents duplicate events for same document + type + date
// sparse: true allows multiple docs with null relatedDocumentId (manual events)
eventSchema.index(
    { relatedDocumentId: 1, type: 1, startDate: 1 },
    { unique: true, sparse: true, name: 'dedup_document_event' }
);

// REVIEW EXPIRY INDEX: Scheduler efficiently finds stale unreviewed events
eventSchema.index({ needsReview: 1, createdAt: 1 });

export default mongoose.model<IEvent>('Event', eventSchema);
