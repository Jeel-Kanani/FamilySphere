import mongoose, { Schema, Document } from 'mongoose';

export enum FactSourceType {
    DOCUMENT = 'document',
    EXPENSE = 'expense',
    EVENT = 'event',
    MANUAL = 'manual'
}

export enum FactType {
    IDENTITY = 'identity',
    FINANCIAL = 'financial',
    LEGAL = 'legal',
    MEDICAL = 'medical',
    EDUCATIONAL = 'educational',
    GENERIC = 'generic'
}

export enum FactStatus {
    PENDING_REVIEW = 'pending_review',
    CONFIRMED = 'confirmed',
    ARCHIVED = 'archived'
}

export interface IIntelligenceFact extends Document {
    familyId: mongoose.Types.ObjectId;
    userId: mongoose.Types.ObjectId;
    sourceType: FactSourceType;
    sourceId: mongoose.Types.ObjectId;
    factType: FactType;
    data: Record<string, any>;
    confidence: number;
    aiModel: string;
    tags: string[];
    status: FactStatus;
    createdAt: Date;
    updatedAt: Date;
}

const IntelligenceFactSchema: Schema = new Schema({
    familyId: { type: Schema.Types.ObjectId, ref: 'Family', required: true, index: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    sourceType: { 
        type: String, 
        enum: Object.values(FactSourceType), 
        required: true,
        index: true 
    },
    sourceId: { type: Schema.Types.ObjectId, required: true, index: true },
    factType: { 
        type: String, 
        enum: Object.values(FactType), 
        default: FactType.GENERIC,
        index: true 
    },
    data: { type: Schema.Types.Mixed, default: {} },
    confidence: { type: Number, default: 0.0 },
    aiModel: { type: String, default: 'unknown' },
    tags: { type: [String], default: [], index: true },
    status: { 
        type: String, 
        enum: Object.values(FactStatus), 
        default: FactStatus.PENDING_REVIEW,
        index: true 
    }
}, {
    timestamps: true
});

// Compound index for unique facts per source if needed
// IntelligenceFactSchema.index({ sourceId: 1, sourceType: 1, factType: 1 });

export default mongoose.model<IIntelligenceFact>('IntelligenceFact', IntelligenceFactSchema);
