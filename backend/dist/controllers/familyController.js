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
exports.getFamilyActivity = exports.updateFamilySettings = exports.updateInviteCode = exports.leaveFamily = exports.transferOwnership = exports.updateMemberRole = exports.removeFamilyMember = exports.getFamilyMembers = exports.getFamily = exports.joinFamilyWithInvite = exports.joinFamily = exports.createFamily = void 0;
const Family_1 = __importDefault(require("../models/Family"));
const User_1 = __importDefault(require("../models/User"));
const FamilyActivity_1 = __importDefault(require("../models/FamilyActivity"));
const Invite_1 = __importDefault(require("../models/Invite"));
function logFamilyActivity(params) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const actor = yield User_1.default.findById(params.actorId).select('name');
            yield FamilyActivity_1.default.create({
                familyId: params.familyId,
                actorId: params.actorId,
                actorName: (actor === null || actor === void 0 ? void 0 : actor.name) || '',
                type: params.type,
                message: params.message,
                metadata: params.metadata || {},
            });
        }
        catch (e) {
            // Best-effort logging: do not fail the request
            console.error('Activity log error:', e);
        }
    });
}
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
        yield logFamilyActivity({
            familyId: family._id.toString(),
            actorId: userId,
            type: 'family_created',
            message: `Created the family "${family.name}"`,
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
        yield logFamilyActivity({
            familyId: family._id.toString(),
            actorId: userId,
            type: 'member_joined',
            message: 'Joined the family',
        });
        res.json(family);
    }
    catch (error) {
        console.error('Join family error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.joinFamily = joinFamily;
// Join family with secure invite (QR/Code/Link)
const joinFamilyWithInvite = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        const { token, code } = req.body;
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        let query = {};
        if (token) {
            query.token = token;
        }
        else if (code) {
            query.code = String(code).toUpperCase();
        }
        else {
            return res.status(400).json({ message: 'Token or code is required' });
        }
        const invite = yield Invite_1.default.findOne(query);
        if (!invite) {
            return res.status(404).json({ message: 'Invite not found or expired' });
        }
        if (invite.usedCount >= invite.maxUses) {
            return res.status(400).json({ message: 'Invite has already been used' });
        }
        if (new Date() > invite.expiresAt) {
            return res.status(400).json({ message: 'Invite has expired' });
        }
        const family = yield Family_1.default.findById(invite.familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        // Check if user already in a family
        const user = yield User_1.default.findById(userId);
        if (user === null || user === void 0 ? void 0 : user.familyId) {
            return res.status(400).json({ message: 'You already belong to a family' });
        }
        // Join family
        family.memberIds.push(userId);
        yield family.save();
        // Update user
        yield User_1.default.findByIdAndUpdate(userId, {
            familyId: family._id,
            role: 'member'
        });
        // Update invite
        invite.usedCount += 1;
        yield invite.save();
        yield logFamilyActivity({
            familyId: family._id.toString(),
            actorId: userId,
            type: 'member_joined',
            message: `Joined the family via ${invite.type} invite`,
        });
        res.json(family);
    }
    catch (error) {
        console.error('Join family with invite error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.joinFamilyWithInvite = joinFamilyWithInvite;
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
// Remove member (admin only)
const removeFamilyMember = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b;
    try {
        const { familyId, userId } = req.params;
        const requesterId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!requesterId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        const requester = yield User_1.default.findById(requesterId);
        if (!requester || ((_b = requester.familyId) === null || _b === void 0 ? void 0 : _b.toString()) !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }
        if (requester.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can remove members' });
        }
        // Prevent removing self or creator
        if (requesterId === userId || family.createdBy.toString() === userId) {
            return res.status(400).json({ message: 'Cannot remove this member' });
        }
        family.memberIds = family.memberIds.filter(id => id.toString() !== userId);
        yield family.save();
        yield User_1.default.findByIdAndUpdate(userId, {
            $unset: { familyId: '', role: '' }
        });
        yield logFamilyActivity({
            familyId,
            actorId: requesterId,
            type: 'member_removed',
            message: `Removed a member from the family`,
            metadata: { memberId: userId },
        });
        return res.json({ message: 'Member removed' });
    }
    catch (error) {
        console.error('Remove member error:', error);
        return res.status(500).json({ message: error.message });
    }
});
exports.removeFamilyMember = removeFamilyMember;
// Update member role (admin only)
const updateMemberRole = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b, _c;
    try {
        const { familyId, userId } = req.params;
        const { role } = req.body;
        const requesterId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!requesterId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        if (!role || !['admin', 'member'].includes(role)) {
            return res.status(400).json({ message: 'Invalid role' });
        }
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        const requester = yield User_1.default.findById(requesterId);
        if (!requester || ((_b = requester.familyId) === null || _b === void 0 ? void 0 : _b.toString()) !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }
        if (requester.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can change roles' });
        }
        if (family.createdBy.toString() === userId) {
            return res.status(400).json({ message: 'Cannot change role of family creator' });
        }
        const target = yield User_1.default.findById(userId);
        if (!target || ((_c = target.familyId) === null || _c === void 0 ? void 0 : _c.toString()) !== familyId) {
            return res.status(404).json({ message: 'Member not found' });
        }
        target.role = role;
        yield target.save();
        yield logFamilyActivity({
            familyId,
            actorId: requesterId,
            type: 'role_changed',
            message: `Updated a member role to ${role}`,
            metadata: { memberId: userId, role },
        });
        return res.json({ message: 'Role updated', role });
    }
    catch (error) {
        console.error('Update member role error:', error);
        return res.status(500).json({ message: error.message });
    }
});
exports.updateMemberRole = updateMemberRole;
// Transfer ownership (creator only)
const transferOwnership = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b;
    try {
        const { familyId, userId } = req.params;
        const requesterId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!requesterId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        if (family.createdBy.toString() !== requesterId) {
            return res.status(403).json({ message: 'Only the creator can transfer ownership' });
        }
        if (family.createdBy.toString() === userId) {
            return res.status(400).json({ message: 'Already the owner' });
        }
        const target = yield User_1.default.findById(userId);
        if (!target || ((_b = target.familyId) === null || _b === void 0 ? void 0 : _b.toString()) !== familyId) {
            return res.status(404).json({ message: 'Member not found' });
        }
        // Update family creator
        family.createdBy = target._id;
        yield family.save();
        // Update roles: new owner admin, old owner member
        yield User_1.default.findByIdAndUpdate(target._id, { role: 'admin' });
        yield User_1.default.findByIdAndUpdate(requesterId, { role: 'member' });
        yield logFamilyActivity({
            familyId,
            actorId: requesterId,
            type: 'ownership_transferred',
            message: `Transferred ownership to ${target.name || 'a member'}`,
            metadata: { newOwnerId: userId },
        });
        return res.json({ message: 'Ownership transferred', familyId: family._id, createdBy: family.createdBy });
    }
    catch (error) {
        console.error('Transfer ownership error:', error);
        return res.status(500).json({ message: error.message });
    }
});
exports.transferOwnership = transferOwnership;
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
        yield logFamilyActivity({
            familyId: String(familyId),
            actorId: userId,
            type: 'member_left',
            message: 'Left the family',
        });
        res.json({ message: 'Left family successfully' });
    }
    catch (error) {
        console.error('Leave family error:', error);
        res.status(500).json({ message: error.message });
    }
});
exports.leaveFamily = leaveFamily;
// Update invite code
const updateInviteCode = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b;
    try {
        const { familyId } = req.params;
        const { inviteCode } = req.body;
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        const user = yield User_1.default.findById(userId);
        if (!user || ((_b = user.familyId) === null || _b === void 0 ? void 0 : _b.toString()) !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }
        if (user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can update invite code' });
        }
        const newCode = inviteCode ? String(inviteCode).toUpperCase() : generateInviteCode();
        if (newCode.length !== 6) {
            return res.status(400).json({ message: 'Invite code must be 6 characters' });
        }
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        family.inviteCode = newCode;
        yield family.save();
        yield logFamilyActivity({
            familyId,
            actorId: userId,
            type: 'invite_regenerated',
            message: 'Regenerated the invite code',
        });
        return res.json({ inviteCode: family.inviteCode });
    }
    catch (error) {
        console.error('Update invite code error:', error);
        return res.status(500).json({ message: error.message });
    }
});
exports.updateInviteCode = updateInviteCode;
// Update family settings (admin only)
const updateFamilySettings = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b, _c;
    try {
        const { familyId } = req.params;
        const { allowMemberInvites, requireApproval } = req.body;
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        const user = yield User_1.default.findById(userId);
        if (!user || ((_b = user.familyId) === null || _b === void 0 ? void 0 : _b.toString()) !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }
        if (user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can update settings' });
        }
        const family = yield Family_1.default.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }
        const settings = (_c = family.settings) !== null && _c !== void 0 ? _c : { allowMemberInvites: true, requireApproval: false };
        if (typeof allowMemberInvites === 'boolean') {
            settings.allowMemberInvites = allowMemberInvites;
        }
        if (typeof requireApproval === 'boolean') {
            settings.requireApproval = requireApproval;
        }
        family.settings = settings;
        yield family.save();
        yield logFamilyActivity({
            familyId,
            actorId: userId,
            type: 'settings_updated',
            message: 'Updated family settings',
            metadata: { allowMemberInvites, requireApproval },
        });
        return res.json(family);
    }
    catch (error) {
        console.error('Update settings error:', error);
        return res.status(500).json({ message: error.message });
    }
});
exports.updateFamilySettings = updateFamilySettings;
// Get family activity feed
const getFamilyActivity = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b;
    try {
        const { familyId } = req.params;
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        const user = yield User_1.default.findById(userId);
        if (!user || ((_b = user.familyId) === null || _b === void 0 ? void 0 : _b.toString()) !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }
        const limitParam = Array.isArray(req.query.limit) ? req.query.limit[0] : req.query.limit;
        const limit = Math.min(Number(limitParam) || 30, 100);
        const activities = yield FamilyActivity_1.default.find({ familyId })
            .sort({ createdAt: -1 })
            .limit(limit)
            .lean();
        return res.json({ activities });
    }
    catch (error) {
        console.error('Get activity error:', error);
        return res.status(500).json({ message: error.message });
    }
});
exports.getFamilyActivity = getFamilyActivity;
// Generate random invite code
function generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}
