import { Request, Response } from 'express';
import Invite from '../models/Invite';
import Family from '../models/Family';
import User from '../models/User';
import crypto from 'crypto';

// Create a new invite
export const createInvite = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const { type, expiresAt, maxUses } = req.body;
        const userId = (req as any).user?.id;

        const family = await Family.findById(familyId);
        if (!family) {
            return res.status(404).json({ message: 'Family not found' });
        }

        const user = await User.findById(userId);
        if (!user || user.familyId?.toString() !== familyId) {
            return res.status(403).json({ message: 'Not allowed' });
        }

        // Only admins can create invites unless settings allow
        if (user.role !== 'admin' && !family.settings?.allowMemberInvites) {
            return res.status(403).json({ message: 'Only admins can create invites' });
        }

        const token = crypto.randomBytes(32).toString('hex');
        let code = '';
        if (type === 'code') {
            code = crypto.randomInt(100000, 999999).toString();
        }

        const invite = await Invite.create({
            familyId,
            type,
            token,
            code: type === 'code' ? code : undefined,
            createdBy: userId,
            expiresAt: expiresAt || new Date(Date.now() + 10 * 60 * 1000), // Default 10 mins
            maxUses: maxUses || 1
        });

        res.status(201).json(invite);
    } catch (error: any) {
        console.error('Create invite error:', error);
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
            type: invite.type
        });
    } catch (error: any) {
        console.error('Validate invite error:', error);
        res.status(500).json({ message: error.message });
    }
};
