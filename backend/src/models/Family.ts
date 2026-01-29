import { Schema, model } from 'mongoose';

const familySchema = new Schema({
    name: {
        type: String,
        required: true,
        trim: true
    },
    createdBy: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    memberIds: [{
        type: Schema.Types.ObjectId,
        ref: 'User'
    }],
    inviteCode: {
        type: String,
        required: true,
        unique: true,
        uppercase: true
    },
    settings: {
        allowMemberInvites: {
            type: Boolean,
            default: true
        },
        requireApproval: {
            type: Boolean,
            default: false
        }
    }
}, {
    timestamps: true
});

export default model('Family', familySchema);
