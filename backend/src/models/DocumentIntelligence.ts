import mongoose, { Schema, Document } from 'mongoose';

// ── Allowed master types (AI must pick from this list) ────────────────────────
export const ALLOWED_DOC_TYPES = [
    // Identity
    'Aadhaar', 'PAN Card', 'Passport', 'Driving License', 'Voter ID',
    // Financial
    'Bank Statement', 'Loan Agreement', 'Insurance Policy', 'Investment Document',
    'Salary Slip', 'Tax Return',
    // Bills & Receipts
    'Electricity Bill', 'Water Bill', 'Gas Bill',
    'Purchase Receipt', 'Invoice', 'Warranty Card', 'Shopping Bill',
    'Restaurant Bill', 'Medical Bill', 'Hospital Bill',
    'School Fee Receipt', 'College Fee Receipt',
    'Rent Receipt', 'Maintenance Bill', 'Internet Bill', 'Mobile Bill',
    // Medical
    'Lab Report', 'Prescription', 'Medical Certificate', 'Vaccination Record',
    'Discharge Summary', 'Health Insurance Card',
    // Legal & Property
    'Rent Agreement', 'Property Deed', 'Affidavit', 'Contract',
    'Legal Notice', 'Court Document', 'NOC', 'Power of Attorney',
    // Academic & Career
    'Marksheet', 'Degree Certificate', 'Admission Letter',
    'Offer Letter', 'Appointment Letter', 'Experience Letter',
    'Resignation Letter', 'Relieving Letter',
    // Vehicle
    'Vehicle RC', 'Vehicle Insurance', 'Pollution Certificate',
    // Other
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
        document_type: string;
        category: DocCategory;
        subcategory?: string;
        confidence: number;            // 0.0 – 1.0
        reasoning: string;
    };

    entities: {
        // Flattened for legacy/quick access
        person_name?: string;
        id_number?: string;
        policy_number?: string;
        registration_number?: string;
        account_number?: string;
        issued_by?: string;
        issue_date?: Date;
        expiry_date?: Date;
        due_date?: Date;
        amount?: number;
        institution?: string;
        address?: string;
        dob?: Date;
        phone?: string;
        purchase_date?: Date;
        warranty_expiry_date?: Date;
        product_name?: string;
        seller_name?: string;
        serial_number?: string;
        warranty_years?: number;

        // Rich Plural Arrays (Future AI Bot Ready)
        people: { name: string | null; role: string | null; confidence: number }[];
        organizations: { name: string | null; type: string | null; confidence: number }[];
        id_numbers: { value: string | null; type: string | null; confidence: number }[];
        locations: { value: string | null; confidence: number }[];
        financial_details?: {
            amounts: { value: number | null; currency: string; confidence: number }[];
            account_numbers: { value: string | null; confidence: number }[];
        };
        important_dates: { label: string | null; value: Date | null; confidence: number }[];
    };

    summary?: string;                  // Brief overview for AI Bot
    tags: string[];                    // e.g. ["identity_critical", "financial_critical"]

    importance: {
        score: number;                 // 1–10
        criticality: 'low' | 'medium' | 'high' | 'critical';
        lifecycle_stage: string;       // e.g. "active", "expiring-soon", "expired"
        renewal_window_days?: number;  // how many days before expiry to remind
    };

    suggested_events: ISuggestedEvent[];

    needs_confirmation: boolean;       // true when confidence < 0.75
    confirmation_tier: 'auto' | 'assist' | 'unknown';  // routing result from pipeline
    ai_model: string;
    analyzed_at: Date;
    raw_ai_response?: string;          // stored for debugging
}

// ── Schema ────────────────────────────────────────────────────────────────────
const SuggestedEventSchema = new Schema({
    title: { type: String, required: true },
    date: { type: Date, required: true },
    event_type: { type: String, enum: ['expiry', 'renewal', 'payment', 'follow_up', 'milestone'] },
    reason: { type: String },
    accepted: { type: Boolean, default: false },
}, { _id: false });

const DocumentIntelligenceSchema = new Schema(
    {
        documentId: { type: Schema.Types.ObjectId, ref: 'Document', required: true, unique: true },
        familyId: { type: Schema.Types.ObjectId, ref: 'Family', required: true },

        classification: {
            document_type: { type: String, default: 'Other' },
            category: { type: String, enum: DOC_CATEGORIES, default: 'Other' },
            subcategory: { type: String },
            confidence: { type: Number, default: 0 },
            reasoning: { type: String, default: '' },
        },

        entities: {
            person_name: { type: String },
            id_number: { type: String },
            policy_number: { type: String },
            registration_number: { type: String },
            account_number: { type: String },
            issued_by: { type: String },
            issue_date: { type: Date },
            expiry_date: { type: Date },
            due_date: { type: Date },
            amount: { type: Number },
            institution: { type: String },
            address: { type: String },
            dob: { type: Date },
            phone: { type: String },
            purchase_date: { type: Date },
            warranty_expiry_date: { type: Date },
            product_name: { type: String },
            seller_name: { type: String },
            serial_number: { type: String },
            warranty_years: { type: Number },

            // Plural arrays
            people: [{
                name: { type: String },
                role: { type: String },
                confidence: { type: Number },
            }],
            organizations: [{
                name: { type: String },
                type: { type: String },
                confidence: { type: Number },
            }],
            id_numbers: [{
                value: { type: String },
                type: { type: String },
                confidence: { type: Number },
            }],
            locations: [{
                value: { type: String },
                confidence: { type: Number },
            }],
            financial_details: {
                amounts: [{
                    value: { type: Number },
                    currency: { type: String, default: 'INR' },
                    confidence: { type: Number },
                }],
                account_numbers: [{
                    value: { type: String },
                    confidence: { type: Number },
                }],
            },
            important_dates: [{
                label: { type: String },
                value: { type: Date },
                confidence: { type: Number },
            }],
        },

        summary: { type: String },
        tags: [{ type: String }],

        importance: {
            score: { type: Number, default: 5 },
            criticality: { type: String, enum: ['low', 'medium', 'high', 'critical'], default: 'medium' },
            lifecycle_stage: { type: String, default: 'active' },
            renewal_window_days: { type: Number },
        },

        suggested_events: [SuggestedEventSchema],

        needs_confirmation: { type: Boolean, default: false },
        confirmation_tier: { type: String, enum: ['auto', 'assist', 'unknown'], default: 'auto' },
        ai_model: { type: String, default: 'gemini-2.0-flash' },
        analyzed_at: { type: Date, default: Date.now },
        raw_ai_response: { type: String },
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
