import mongoose, { Schema, Document } from 'mongoose';

export interface IDocument extends Document {
    title: String;
    category: String;
    folder: String;
    memberId?: mongoose.Types.ObjectId;
    fileUrl: String;
    fileType: String;
    fileSize: number;
    cloudinaryId: String;
    familyId: mongoose.Types.ObjectId;
    uploadedBy: mongoose.Types.ObjectId;
    deleted: boolean;
    deletedAt?: Date;
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
        fileSize: { type: Number, required: true }, // in bytes
        cloudinaryId: { type: String, required: true },
        familyId: { type: Schema.Types.ObjectId, ref: 'Family', required: true },
        uploadedBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
        deleted: { type: Boolean, default: false },
        deletedAt: { type: Date },
    },
    { timestamps: true }
);

export default mongoose.model<IDocument>('Document', documentSchema);
