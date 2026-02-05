"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = require("mongoose");
const familyActivitySchema = new mongoose_1.Schema({
    familyId: {
        type: mongoose_1.Schema.Types.ObjectId,
        ref: 'Family',
        required: true,
    },
    actorId: {
        type: mongoose_1.Schema.Types.ObjectId,
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
        type: mongoose_1.Schema.Types.Mixed,
        default: {},
    },
}, {
    timestamps: true,
});
exports.default = (0, mongoose_1.model)('FamilyActivity', familyActivitySchema);
