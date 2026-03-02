import mongoose, { Schema, Document } from 'mongoose';

export interface IDocument extends Document {
    title: string;
    category: string;
    folder: string;
    memberId?: mongoose.Types.ObjectId;
    fileUrl: string;
    fileType: string;
    fileSize: number;
    cloudinaryId: string;
    familyId: mongoose.Types.ObjectId;
    uploadedBy: mongoose.Types.ObjectId;
    deleted: boolean;
    deletedAt?: Date;

    // Advanced Tracking Fields
    docType: string; // e.g. 'electricity_bill', 'passport'
    expiryDate?: Date;
    dueDate?: Date;
    reminderEnabled: boolean;
    reminderBeforeDays: number;
    amount?: number;
    isPaid: boolean;
    repeatType: 'none' | 'monthly' | 'yearly';
    rawText?: string;

    // Phase 4 – background queue tracking
    ocrStatus: 'pending' | 'processing' | 'done' | 'failed' | 'needs_confirmation';
    ocrJobId?: string;
    ocrConfidence?: number;

    createdAt: Date;
    updatedAt: Date;
}

const documentSchema: Schema = new Schema(
    {
        title: { type: String, required: true },
        category: { type: String, required: true },
        folder: { type: String, default: 'General' },
        memberId: { type: Schema.Types.ObjectId, ref: 'User' },
        fileUrl: { type: String, required: true },
        fileType: { type: String, required: true },
        fileSize: { type: Number, required: true },
        cloudinaryId: { type: String, required: true },
        familyId: { type: Schema.Types.ObjectId, ref: 'Family', required: true },
        uploadedBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
        deleted: { type: Boolean, default: false },
        deletedAt: { type: Date },

        // Advanced Tracking Implementation
        docType: { type: String, default: 'unknown' },
        expiryDate: { type: Date },
        dueDate: { type: Date },
        reminderEnabled: { type: Boolean, default: false },
        reminderBeforeDays: { type: Number, default: 7 },
        amount: { type: Number },
        isPaid: { type: Boolean, default: false },
        repeatType: {
            type: String,
            enum: ['none', 'monthly', 'yearly'],
            default: 'none',
        },
        rawText: { type: String },

        // Phase 4 – background queue tracking
        ocrStatus: {
            type: String,
            enum: ['pending', 'processing', 'done', 'failed', 'needs_confirmation'],
            default: 'pending',
        },
        ocrJobId:      { type: String },
        ocrConfidence: { type: Number },
    },
    { timestamps: true }
);

export default mongoose.model<IDocument>('Document', documentSchema);
