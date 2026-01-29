"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.leaveFamily = exports.getFamilyMembers = exports.getFamily = exports.joinFamily = exports.createFamily = void 0;
const Family_1 = __importDefault(require("../models/Family"));
const User_1 = __importDefault(require("../models/User"));
// Create a new family
const createFamily = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        const { name, inviteCode } = req.body;
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        // Check if user already has a family
        const user = yield User_1.default.findById(userId);
        if (user === null || user === void 0 ? void 0 : user.familyId) {
            return res.status(400).json({ message: 'User already belongs to a family' });
        }
        // Create family
        const family = yield Family_1.default.create({
            name,
            createdBy: userId,
            memberIds: [userId],
            inviteCode: inviteCode || generateInviteCode()
        });
        // Update user with family ID and role
        yield User_1.default.findByIdAndUpdate(userId, {
            familyId: family._id,
            role: 'admin'
        });
        res.status(201).json(family);
    }
    catch (error) {
        console.error('Create family error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.createFamily = createFamily;
// Join a family using invite code
const joinFamily = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        const { inviteCode } = req.body;
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        // Find family by invite code
        const family = yield Family_1.default.findOne({ inviteCode: inviteCode.toUpperCase() });
        if (!family) {
            return res.status(404).json({ message: 'Invalid invite code' });
        }
        // Check if user already in family
        if (family.memberIds.includes(userId)) {
            return res.status(400).json({ message: 'Already a member of this family' });
        }
        // Add user to family
        family.memberIds.push(userId);
        yield family.save();
        // Update user
        yield User_1.default.findByIdAndUpdate(userId, {
            familyId: family._id,
            role: 'member'
        });
        res.json(family);
    }
    catch (error) {
        console.error('Join family error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.joinFamily = joinFamily;
// Get family by ID
const getFamily = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { familyId } = req.params;
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        res.json(family);
    }
    catch (error) {
        console.error('Get family error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.getFamily = getFamily;
// Get family members
const getFamilyMembers = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { familyId } = req.params;
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        // Get all member details
        const members = yield User_1.default.find({ _id: { $in: family.memberIds } })
            .select('_id name email role createdAt');
        res.json({ members });
    }
    catch (error) {
        console.error('Get family members error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.getFamilyMembers = getFamilyMembers;
// Leave family
const leaveFamily = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        const { familyId } = req.params;
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        // Remove user from family
        family.memberIds = family.memberIds.filter(id => id.toString() !== userId);
        yield family.save();
        // Update user
        yield User_1.default.findByIdAndUpdate(userId, {
            $unset: { familyId: '', role: '' }
        });
        res.json({ message: 'Left family successfully' });
    }
    catch (error) {
        console.error('Leave family error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.leaveFamily = leaveFamily;
// Generate random invite code
function generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}
