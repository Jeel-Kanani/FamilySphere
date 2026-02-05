import { Request, Response } from 'express';
import Family from '../models/Family';
import User from '../models/User';
import FamilyActivity from '../models/FamilyActivity';

async function logFamilyActivity(params: {
    familyId: string;
    actorId: string;
    type: string;
    message: string;
    metadata?: Record<string, any>;
}) {
    try {
        const actor = await User.findById(params.actorId).select('name');
        await FamilyActivity.create({
            familyId: params.familyId,
            actorId: params.actorId,
            actorName: actor?.name || '',
            type: params.type,
            message: params.message,
            metadata: params.metadata || {},
        });
    } catch (e) {
        // Best-effort logging: do not fail the request
        console.error('Activity log error:', e);
    }
}

// Create a new family
export const createFamily = async (req: Request, res: Response) => {
    try {
        const { name, inviteCode } = req.body;
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        // Check if user already has a family
        const user = await User.findById(userId);
        if (user?.familyId) {
            return res.status(400).json({ message: 'User already belongs to a family' });
        }

        // Create family
        const family = await Family.create({
            name,
            createdBy: userId,
            memberIds: [userId],
            inviteCode: inviteCode || generateInviteCode()
        });

        // Update user with family ID and role
        await User.findByIdAndUpdate(userId, {
            familyId: family._id,
            role: 'admin'
        });

        await logFamilyActivity({
            familyId: family._id.toString(),
            actorId: userId,
            type: 'family_created',
            message: `Created the family "${family.name}"`,
        });

        res.status(201).json(family);
    } catch (error: any) {
        console.error('Create family error:', error);
        res.status(500).json({ message: error.message });
    }
};

// Join a family using invite code
export const joinFamily = async (req: Request, res: Response) => {
    try {
        const { inviteCode } = req.body;
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        // Find family by invite code
        const family = await Family.findOne({ inviteCode: inviteCode.toUpperCase() });
        if (!family) {
            return res.status(404).json({ message: 'Invalid invite code' });
        }

        // Check if user already in family
        if (family.memberIds.includes(userId as any)) {
            return res.status(400).json({ message: 'Already a member of this family' });
        }

        // Add user to family
        family.memberIds.push(userId as any);
        await family.save();

        // Update user
        await User.findByIdAndUpdate(userId, {
            familyId: family._id,
            role: 'member'
        });

        await logFamilyActivity({
            familyId: family._id.toString(),
            actorId: userId,
            type: 'member_joined',
            message: 'Joined the family',
        });

        res.json(family);
    } catch (error: any) {
        console.error('Join family error:', error);
        res.status(500).json({ message: error.message });
    }
};

// Get family by ID
export const getFamily = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const family = await Family.findById(familyId);

        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        res.json(family);
    } catch (error: any) {
        console.error('Get family error:', error);
        res.status(500).json({ message: error.message });
    }
};

// Get family members
export const getFamilyMembers = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        // Get all member details
        const members = await User.find({ _id: { $in: family.memberIds } })
            .select('_id name email role createdAt');

        res.json({ members });
    } catch (error: any) {
        console.error('Get family members error:', error);
        res.status(500).json({ message: error.message });
    }
};

// Remove member (admin only)
export const removeFamilyMember = async (req: Request, res: Response) => {
    try {
        const { familyId, userId } = req.params;
        const requesterId = (req as any).user?.id;

        if (!requesterId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        const requester = await User.findById(requesterId);
        if (!requester || requester.familyId?.toString() !== familyId) {
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
        await family.save();

        await User.findByIdAndUpdate(userId, {
            $unset: { familyId: '', role: '' }
        });

        await logFamilyActivity({
            familyId,
            actorId: requesterId,
            type: 'member_removed',
            message: `Removed a member from the family`,
            metadata: { memberId: userId },
        });

        return res.json({ message: 'Member removed' });
    } catch (error: any) {
        console.error('Remove member error:', error);
        return res.status(500).json({ message: error.message });
    }
};

// Update member role (admin only)
export const updateMemberRole = async (req: Request, res: Response) => {
    try {
        const { familyId, userId } = req.params;
        const { role } = req.body;
        const requesterId = (req as any).user?.id;

        if (!requesterId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        if (!role || !['admin', 'member'].includes(role)) {
            return res.status(400).json({ message: 'Invalid role' });
        }

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        const requester = await User.findById(requesterId);
        if (!requester || requester.familyId?.toString() !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }

        if (requester.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can change roles' });
        }

        if (family.createdBy.toString() === userId) {
            return res.status(400).json({ message: 'Cannot change role of family creator' });
        }

        const target = await User.findById(userId);
        if (!target || target.familyId?.toString() !== familyId) {
            return res.status(404).json({ message: 'Member not found' });
        }

        target.role = role;
        await target.save();

        await logFamilyActivity({
            familyId,
            actorId: requesterId,
            type: 'role_changed',
            message: `Updated a member role to ${role}`,
            metadata: { memberId: userId, role },
        });

        return res.json({ message: 'Role updated', role });
    } catch (error: any) {
        console.error('Update member role error:', error);
        return res.status(500).json({ message: error.message });
    }
};

// Transfer ownership (creator only)
export const transferOwnership = async (req: Request, res: Response) => {
    try {
        const { familyId, userId } = req.params;
        const requesterId = (req as any).user?.id;

        if (!requesterId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        if (family.createdBy.toString() !== requesterId) {
            return res.status(403).json({ message: 'Only the creator can transfer ownership' });
        }

        if (family.createdBy.toString() === userId) {
            return res.status(400).json({ message: 'Already the owner' });
        }

        const target = await User.findById(userId);
        if (!target || target.familyId?.toString() !== familyId) {
            return res.status(404).json({ message: 'Member not found' });
        }

        // Update family creator
        family.createdBy = target._id;
        await family.save();

        // Update roles: new owner admin, old owner member
        await User.findByIdAndUpdate(target._id, { role: 'admin' });
        await User.findByIdAndUpdate(requesterId, { role: 'member' });

        await logFamilyActivity({
            familyId,
            actorId: requesterId,
            type: 'ownership_transferred',
            message: `Transferred ownership to ${target.name || 'a member'}`,
            metadata: { newOwnerId: userId },
        });

        return res.json({ message: 'Ownership transferred', familyId: family._id, createdBy: family.createdBy });
    } catch (error: any) {
        console.error('Transfer ownership error:', error);
        return res.status(500).json({ message: error.message });
    }
};

// Leave family
export const leaveFamily = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        // Remove user from family
        family.memberIds = family.memberIds.filter(id => id.toString() !== userId);
        await family.save();

        // Update user
        await User.findByIdAndUpdate(userId, {
            $unset: { familyId: '', role: '' }
        });

        await logFamilyActivity({
            familyId: String(familyId),
            actorId: userId,
            type: 'member_left',
            message: 'Left the family',
        });

        res.json({ message: 'Left family successfully' });
    } catch (error: any) {
        console.error('Leave family error:', error);
        res.status(500).json({ message: error.message });
    }
};

// Update invite code
export const updateInviteCode = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const { inviteCode } = req.body;
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const user = await User.findById(userId);
        if (!user || user.familyId?.toString() !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }

        if (user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can update invite code' });
        }

        const newCode = inviteCode ? String(inviteCode).toUpperCase() : generateInviteCode();
        if (newCode.length !== 6) {
            return res.status(400).json({ message: 'Invite code must be 6 characters' });
        }

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        family.inviteCode = newCode;
        await family.save();

        await logFamilyActivity({
            familyId,
            actorId: userId,
            type: 'invite_regenerated',
            message: 'Regenerated the invite code',
        });

        return res.json({ inviteCode: family.inviteCode });
    } catch (error: any) {
        console.error('Update invite code error:', error);
        return res.status(500).json({ message: error.message });
    }
};

// Update family settings (admin only)
export const updateFamilySettings = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const { allowMemberInvites, requireApproval } = req.body;
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const user = await User.findById(userId);
        if (!user || user.familyId?.toString() !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }

        if (user.role !== 'admin') {
            return res.status(403).json({ message: 'Only admins can update settings' });
        }

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        const settings = family.settings ?? { allowMemberInvites: true, requireApproval: false };
        if (typeof allowMemberInvites === 'boolean') {
            settings.allowMemberInvites = allowMemberInvites;
        }
        if (typeof requireApproval === 'boolean') {
            settings.requireApproval = requireApproval;
        }
        family.settings = settings as any;

        await family.save();

        await logFamilyActivity({
            familyId,
            actorId: userId,
            type: 'settings_updated',
            message: 'Updated family settings',
            metadata: { allowMemberInvites, requireApproval },
        });

        return res.json(family);
    } catch (error: any) {
        console.error('Update settings error:', error);
        return res.status(500).json({ message: error.message });
    }
};

// Get family activity feed
export const getFamilyActivity = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const userId = (req as any).user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const user = await User.findById(userId);
        if (!user || user.familyId?.toString() !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }

        const limitParam = Array.isArray(req.query.limit) ? req.query.limit[0] : req.query.limit;
        const limit = Math.min(Number(limitParam) || 30, 100);
        const activities = await FamilyActivity.find({ familyId })
            .sort({ createdAt: -1 })
            .limit(limit)
            .lean();

        return res.json({ activities });
    } catch (error: any) {
        console.error('Get activity error:', error);
        return res.status(500).json({ message: error.message });
    }
};

// Generate random invite code
function generateInviteCode(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}
