import { Schema, model } from 'mongoose';

const familyActivitySchema = new Schema({
    familyId: {
        type: Schema.Types.ObjectId,
        ref: 'Family',
        required: true,
    },
    actorId: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    actorName: {
        type: String,
        default: '',
    },
    type: {
        type: String,
        required: true,
    },
    message: {
        type: String,
        required: true,
    },
    metadata: {
        type: Schema.Types.Mixed,
        default: {},
    },
}, {
    timestamps: true,
});

export default model('FamilyActivity', familyActivitySchema);
