import mongoose, { Document, Schema } from 'mongoose';

export interface IEmailOtp extends Document {
    email: string;
    codeHash: string;
    expiresAt: Date;
    verifiedAt?: Date;
    attempts: number;
    lastSentAt: Date;
}

const emailOtpSchema = new Schema<IEmailOtp>({
    email: {
        type: String,
        required: true,
        lowercase: true,
        trim: true,
        index: true,
    },
    codeHash: {
        type: String,
        required: true,
    },
    expiresAt: {
        type: Date,
        required: true,
        index: true,
    },
    verifiedAt: {
        type: Date,
    },
    attempts: {
        type: Number,
        default: 0,
    },
    lastSentAt: {
        type: Date,
        required: true,
    },
}, {
    timestamps: true,
});

// Auto-remove expired OTP docs
emailOtpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const EmailOtp = mongoose.model<IEmailOtp>('EmailOtp', emailOtpSchema);

export default EmailOtp;
