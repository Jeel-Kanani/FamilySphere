import mongoose, { Document, Schema } from 'mongoose';

export interface IChatMessage extends Document {
    familyId: mongoose.Types.ObjectId;
    senderId: mongoose.Types.ObjectId;
    senderName: string;
    content: string;
    type: 'text' | 'image' | 'document' | 'video';
    mediaUrl?: string;
    status: 'sent' | 'delivered' | 'read';
    metadata?: any;
}

const chatMessageSchema = new Schema<IChatMessage>({
    familyId: { type: Schema.Types.ObjectId, ref: 'Family', required: true },
    senderId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    senderName: { type: String, required: true },
    content: { type: String, required: true },
    type: { 
        type: String, 
        enum: ['text', 'image', 'document', 'video'], 
        default: 'text' 
    },
    mediaUrl: { type: String },
    status: { 
        type: String, 
        enum: ['sent', 'delivered', 'read'], 
        default: 'sent' 
    },
    metadata: { type: Schema.Types.Mixed, default: {} }
}, { timestamps: true });

export default mongoose.model<IChatMessage>('ChatMessage', chatMessageSchema);
