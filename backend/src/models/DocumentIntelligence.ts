import mongoose, { Schema, Document } from 'mongoose';

// ── Allowed master types (AI must pick from this list) ────────────────────────
export const ALLOWED_DOC_TYPES = [
    'Aadhaar', 'PAN Card', 'Passport', 'Driving License', 'Voter ID',
    'Bank Statement', 'Loan Agreement', 'Insurance Policy', 'Investment Document',
    'Lab Report', 'Prescription', 'Medical Certificate',
    'Rent Agreement', 'Property Deed', 'Affidavit', 'Contract',
    'Marksheet', 'Degree Certificate', 'Admission Letter',
    'Electricity Bill', 'Water Bill', 'Gas Bill',
    'Salary Slip', 'Tax Return', 'Vehicle RC',
    'Other',
] as const;

export type DocType = typeof ALLOWED_DOC_TYPES[number];

export const DOC_CATEGORIES = [
    'Identity', 'Financial', 'Medical', 'Legal', 'Academic', 'Utility', 'Other',
] as const;

export type DocCategory = typeof DOC_CATEGORIES[number];

// ── Suggested timeline event (from AI) ───────────────────────────────────────
export interface ISuggestedEvent {
    title: string;
    date: Date;
    event_type: 'expiry' | 'renewal' | 'payment' | 'follow_up' | 'milestone';
    reason: string;
    accepted: boolean; // true = created in Event collection, false = rejected by rules
}

// ── Main interface ────────────────────────────────────────────────────────────
export interface IDocumentIntelligence extends Document {
    documentId: mongoose.Types.ObjectId;
    familyId: mongoose.Types.ObjectId;

    classification: {
        doc_type: string;
        category: DocCategory;
        confidence: number;            // 0.0 – 1.0
        reasoning: string;
    };

    entities: {
        person_name?: string;
        id_number?: string;
        issued_by?: string;
        issue_date?: Date;
        expiry_date?: Date;
        due_date?: Date;
        amount?: number;
        institution?: string;
        address?: string;
    };

    tags: string[];                    // e.g. ["identity", "travel", "renewal-required"]

    importance: {
        score: number;                 // 1–10
        criticality: 'low' | 'medium' | 'high' | 'critical';
        lifecycle_stage: string;       // e.g. "active", "expiring-soon", "expired"
        renewal_window_days?: number;  // how many days before expiry to remind
    };

    suggested_events: ISuggestedEvent[];

    needs_confirmation: boolean;       // true when confidence < 0.70
    ai_model: string;
    analyzed_at: Date;
    raw_ai_response?: string;          // stored for debugging
}

// ── Schema ────────────────────────────────────────────────────────────────────
const SuggestedEventSchema = new Schema({
    title:      { type: String, required: true },
    date:       { type: Date, required: true },
    event_type: { type: String, enum: ['expiry', 'renewal', 'payment', 'follow_up', 'milestone'] },
    reason:     { type: String },
    accepted:   { type: Boolean, default: false },
}, { _id: false });

const DocumentIntelligenceSchema = new Schema(
    {
        documentId: { type: Schema.Types.ObjectId, ref: 'Document', required: true, unique: true },
        familyId:   { type: Schema.Types.ObjectId, ref: 'Family', required: true },

        classification: {
            doc_type:   { type: String, default: 'Other' },
            category:   { type: String, enum: DOC_CATEGORIES, default: 'Other' },
            confidence: { type: Number, default: 0 },
            reasoning:  { type: String, default: '' },
        },

        entities: {
            person_name: { type: String },
            id_number:   { type: String },
            issued_by:   { type: String },
            issue_date:  { type: Date },
            expiry_date: { type: Date },
            due_date:    { type: Date },
            amount:      { type: Number },
            institution: { type: String },
            address:     { type: String },
        },

        tags: [{ type: String }],

        importance: {
            score:                { type: Number, default: 5 },
            criticality:          { type: String, enum: ['low', 'medium', 'high', 'critical'], default: 'medium' },
            lifecycle_stage:      { type: String, default: 'active' },
            renewal_window_days:  { type: Number },
        },

        suggested_events: [SuggestedEventSchema],

        needs_confirmation: { type: Boolean, default: false },
        ai_model:           { type: String, default: 'gemini-1.5-flash' },
        analyzed_at:        { type: Date, default: Date.now },
        raw_ai_response:    { type: String },
    },
    { timestamps: true }
);

// Index for fast lookup by document and family
DocumentIntelligenceSchema.index({ documentId: 1 });
DocumentIntelligenceSchema.index({ familyId: 1 });
DocumentIntelligenceSchema.index({ 'classification.doc_type': 1 });
DocumentIntelligenceSchema.index({ tags: 1 });
DocumentIntelligenceSchema.index({ 'importance.criticality': 1 });

export default mongoose.model<IDocumentIntelligence>('DocumentIntelligence', DocumentIntelligenceSchema);
