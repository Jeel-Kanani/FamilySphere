import { Request, Response } from 'express';
import Family from '../models/Family';
import User from '../models/User';

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

        res.json({ message: 'Left family successfully' });
    } catch (error: any) {
        console.error('Leave family error:', error);
        res.status(500).json({ message: error.message });
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
