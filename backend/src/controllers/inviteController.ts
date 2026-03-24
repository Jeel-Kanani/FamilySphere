import { Request, Response } from 'express';
import Invite from '../models/Invite';
import Family from '../models/Family';
import User from '../models/User';
import crypto from 'crypto';
import { sendFamilyInviteEmail } from '../services/emailService';

// Create a new invite
export const createInvite = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const { type, expiresAt, maxUses, recipientEmail, targetRole } = req.body;
        const userId = (req as any).user?._id;

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        const user = await User.findById(userId);
        if (!user || user.familyId?.toString() !== familyId) {
            return res.status(403).json({ message: 'Not allowed to invite for this family' });
        }

        // Generate tokens
        const token = crypto.randomBytes(32).toString('hex');
        const code = crypto.randomInt(100000, 999999).toString();

        // Expire in 48 hours by default as per user request
        const defaultExpiration = new Date(Date.now() + 48 * 60 * 60 * 1000); 

        const invite = await Invite.create({
            familyId,
            type: type || 'link',
            token,
            code,
            createdBy: userId,
            recipientEmail,
            targetRole: targetRole || 'member',
            expiresAt: expiresAt || defaultExpiration,
            maxUses: maxUses || 1
        });

        // Send email if recipient provided
        if (recipientEmail) {
            const inviteUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/join?token=${token}`;
            try {
                await sendFamilyInviteEmail(recipientEmail, user.name, family.name, inviteUrl);
            } catch (emailErr: any) {
                console.warn('Failed to send invite email:', emailErr.message);
            }
        }

        res.status(201).json(invite);
    } catch (error: any) {
        console.error('Create invite error:', error);
        res.status(500).json({ message: error.message });
    }
};

// Get all invites for a family
export const getFamilyInvites = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const userId = (req as any).user?._id;

        const user = await User.findById(userId);
        if (!user || user.familyId?.toString() !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }

        const invites = await Invite.find({ familyId, status: 'pending' })
            .populate('createdBy', 'name email')
            .sort({ createdAt: -1 });

        res.json(invites);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// Revoke an invite
export const revokeInvite = async (req: Request, res: Response) => {
    try {
        const { familyId, inviteId } = req.params;
        const userId = (req as any).user?._id;

        const invite = await Invite.findOne({ _id: inviteId, familyId });
        if (!invite) {
            return res.status(404).json({ message: 'Invite not found' });
        }

        const user = await User.findById(userId);
        // Only admin or the creator can revoke
        if (user?.role !== 'admin' && invite.createdBy.toString() !== userId.toString()) {
            return res.status(403).json({ message: 'Not authorized to revoke this invite' });
        }

        invite.status = 'revoked';
        await invite.save();

        res.json({ message: 'Invite revoked successfully' });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// Validate an invite before joining
export const validateInvite = async (req: Request, res: Response) => {
    try {
        const { token, code } = req.query;

        let query: any = {};
        if (token) {
            query.token = token;
        } else if (code) {
            query.code = String(code).toUpperCase();
        } else {
            return res.status(400).json({ message: 'Token or code is required' });
        }

        const invite = await Invite.findOne(query).populate('familyId', 'name');
        if (!invite) {
            return res.status(404).json({ message: 'Invite not found or expired' });
        }

        if (invite.usedCount >= invite.maxUses) {
            return res.status(400).json({ message: 'Invite has reached max uses' });
        }

        if (new Date() > invite.expiresAt) {
            return res.status(400).json({ message: 'Invite has expired' });
        }

        res.json({
            valid: true,
            family: invite.familyId,
            type: invite.type,
            targetRole: (invite as any).targetRole || 'member'
        });
    } catch (error: any) {
        console.error('Validate invite error:', error);
        res.status(500).json({ message: error.message });
    }
};
