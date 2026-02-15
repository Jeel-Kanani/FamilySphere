"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = require("mongoose");
const familySchema = new mongoose_1.Schema({
    name: {
        type: String,
        required: true,
        trim: true
    },
    createdBy: {
        type: mongoose_1.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    memberIds: [{
            type: mongoose_1.Schema.Types.ObjectId,
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
    },
    storageUsed: {
        type: Number,
        default: 0
    },
    storageLimit: {
        type: Number,
        default: 25 * 1024 * 1024 * 1024 // 25 GB
    }
}, {
    timestamps: true
});
exports.default = (0, mongoose_1.model)('Family', familySchema);
