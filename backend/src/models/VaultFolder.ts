import mongoose, { Schema, Document } from 'mongoose';

export interface IVaultFolder extends Document {
    familyId: mongoose.Types.ObjectId;
    category: string;
    memberId?: mongoose.Types.ObjectId;
    name: string;
    isSystem: boolean;
    deleted: boolean;
    createdAt: Date;
    updatedAt: Date;
}

const vaultFolderSchema: Schema = new Schema(
    {
        familyId: { type: Schema.Types.ObjectId, ref: 'Family', required: true },
        category: { type: String, required: true },
        memberId: { type: Schema.Types.ObjectId, ref: 'User' },
        name: { type: String, required: true },
        isSystem: { type: Boolean, default: false },
        deleted: { type: Boolean, default: false },
    },
    { timestamps: true }
);

vaultFolderSchema.index({ familyId: 1, category: 1, memberId: 1, name: 1 }, { unique: true });

export default mongoose.model<IVaultFolder>('VaultFolder', vaultFolderSchema);
