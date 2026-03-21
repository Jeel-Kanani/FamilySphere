import mongoose, { Document, Schema } from 'mongoose';

export interface IPost extends Document {
    familyId: mongoose.Types.ObjectId;
    creatorId: mongoose.Types.ObjectId;
    content: string;
    mediaUrls: string[];
    type: 'moment' | 'milestone' | 'document_share';
    likes: mongoose.Types.ObjectId[];
    comments: {
        userId: mongoose.Types.ObjectId;
        userName: string;
        text: string;
        createdAt: Date;
    }[];
}

const postSchema = new Schema<IPost>({
    familyId: { type: Schema.Types.ObjectId, ref: 'Family', required: true },
    creatorId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    content: { type: String, required: true },
    mediaUrls: { type: [String], default: [] },
    type: { 
        type: String, 
        enum: ['moment', 'milestone', 'document_share'], 
        default: 'moment' 
    },
    likes: [{ type: Schema.Types.ObjectId, ref: 'User' }],
    comments: [{
        userId: { type: Schema.Types.ObjectId, ref: 'User' },
        userName: String,
        text: String,
        createdAt: { type: Date, default: Date.now }
    }]
}, { timestamps: true });

export default mongoose.model<IPost>('Post', postSchema);
