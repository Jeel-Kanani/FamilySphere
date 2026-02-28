import mongoose from 'mongoose';

export interface IReminder extends mongoose.Document {
    title: string;
    description?: string;
    familyId: mongoose.Types.ObjectId;
    assignedTo: mongoose.Types.ObjectId;
    createdBy: mongoose.Types.ObjectId;
    dateTime: Date;
    repeatType: 'none' | 'daily' | 'weekly' | 'monthly';
    isCompleted: boolean;
    category: 'medicine' | 'habit' | 'task' | 'other';
    createdAt: Date;
    updatedAt: Date;
}

const reminderSchema = new mongoose.Schema({
    title: { type: String, required: true },
    description: { type: String },
    familyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Family', required: true },
    assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    dateTime: { type: Date, required: true },
    repeatType: {
        type: String,
        enum: ['none', 'daily', 'weekly', 'monthly'],
        default: 'none'
    },
    isCompleted: { type: Boolean, default: false },
    category: {
        type: String,
        enum: ['medicine', 'habit', 'task', 'other'],
        default: 'task'
    }
}, { timestamps: true });

export default mongoose.model<IReminder>('Reminder', reminderSchema);
