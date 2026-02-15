import { Schema, model } from 'mongoose';

const inviteSchema = new Schema({
    familyId: {
        type: Schema.Types.ObjectId,
        ref: 'Family',
        required: true
    },
    type: {
        type: String,
        enum: ['qr', 'code', 'link'],
        required: true
    },
    token: {
        type: String,
        required: true,
        unique: true
    },
    code: {
        type: String,
        required: false, // Only for 'code' type
        unique: true,
        sparse: true,
        uppercase: true
    },
    createdBy: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    expiresAt: {
        type: Date,
        required: true
    },
    maxUses: {
        type: Number,
        default: 1
    },
    usedCount: {
        type: Number,
        default: 0
    }
}, {
    timestamps: true
});

// Index to automatically delete expired invites
inviteSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export default model('Invite', inviteSchema);
