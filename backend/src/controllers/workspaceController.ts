import { Request, Response } from 'express';
import Family from '../models/Family';
import User from '../models/User';
import crypto from 'crypto';

const generateInviteCode = () => {
    return 'WS-' + crypto.randomBytes(3).toString('hex').toUpperCase();
};

// @desc    Create a new workspace (team, project, vault, household)
// @route   POST /api/workspaces
// @access  Private
export const createWorkspace = async (req: Request, res: Response) => {
    try {
        const { name, workspaceType = 'team', icon = '🏢', description = '' } = req.body;
        const userId = (req as any).user?.id || (req as any).user?._id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        if (!name || typeof name !== 'string' || name.trim().length === 0) {
            return res.status(400).json({ message: 'Workspace name is required' });
        }

        // Generate invite code
        let inviteCode = generateInviteCode();
        let exists = await Family.findOne({ inviteCode });
        while (exists) {
            inviteCode = generateInviteCode();
            exists = await Family.findOne({ inviteCode });
        }

        // Create the workspace in DB
        const workspace = await Family.create({
            name: name.trim(),
            workspaceType,
            icon,
            description,
            createdBy: userId,
            memberIds: [userId],
            inviteCode,
        });

        // Add to user's workspaces and set as active workspace
        await User.findByIdAndUpdate(userId, {
            familyId: workspace._id,
            role: 'admin',
            $addToSet: {
                workspaces: {
                    workspaceId: workspace._id,
                    role: 'admin',
                    joinedAt: new Date(),
                },
            },
        });

        return res.status(201).json({
            ...workspace.toObject(),
            workspaceId: workspace._id,
            familyId: workspace._id,
            role: 'admin',
        });
    } catch (error: any) {
        console.error('[Workspace] Create error:', error);
        return res.status(500).json({ message: error.message || 'Server error' });
    }
};

// @desc    Get all workspaces the current user belongs to
// @route   GET /api/workspaces/my
// @access  Private
export const getMyWorkspaces = async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.id || (req as any).user?._id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Find all workspaces where user is in memberIds
        const workspaces = await Family.find({ memberIds: userId })
            .sort({ updatedAt: -1 })
            .lean();

        const activeId = user.familyId?.toString();

        const formatted = workspaces.map((w: any) => ({
            id: w._id,
            _id: w._id,
            name: w.name,
            workspaceType: w.workspaceType || 'team',
            icon: w.icon || '🏢',
            description: w.description || '',
            inviteCode: w.inviteCode,
            memberCount: Array.isArray(w.memberIds) ? w.memberIds.length : 1,
            isActive: w._id.toString() === activeId,
            role: w.createdBy?.toString() === userId.toString() ? 'admin' : (user.role || 'member'),
            createdAt: w.createdAt,
        }));

        return res.json({
            workspaces: formatted,
            activeWorkspaceId: activeId,
        });
    } catch (error: any) {
        console.error('[Workspace] getMyWorkspaces error:', error);
        return res.status(500).json({ message: error.message });
    }
};

// @desc    Switch active workspace
// @route   POST /api/workspaces/switch/:id
// @access  Private
export const switchWorkspace = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const userId = (req as any).user?.id || (req as any).user?._id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const workspace = await Family.findOne({ _id: id, memberIds: userId });
        if (!workspace) {
            return res.status(404).json({ message: 'Workspace not found or you are not a member' });
        }

        const role = workspace.createdBy.toString() === userId.toString() ? 'admin' : 'member';

        // Update active familyId
        const updatedUser = await User.findByIdAndUpdate(
            userId,
            { familyId: workspace._id, role },
            { new: true }
        ).select('-password');

        return res.json({
            message: `Switched to workspace: ${workspace.name}`,
            activeWorkspace: workspace,
            user: updatedUser,
        });
    } catch (error: any) {
        return res.status(500).json({ message: error.message });
    }
};

// @desc    Join workspace with invite code
// @route   POST /api/workspaces/join
// @access  Private
export const joinWorkspace = async (req: Request, res: Response) => {
    try {
        const { inviteCode } = req.body;
        const userId = (req as any).user?.id || (req as any).user?._id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        if (!inviteCode || typeof inviteCode !== 'string') {
            return res.status(400).json({ message: 'Invite code is required' });
        }

        const cleanCode = inviteCode.trim().toUpperCase();
        const workspace = await Family.findOne({ inviteCode: cleanCode });

        if (!workspace) {
            return res.status(404).json({ message: 'Invalid workspace invite code' });
        }

        const alreadyMember = workspace.memberIds.some((m) => m.toString() === userId.toString());

        if (!alreadyMember) {
            workspace.memberIds.push(userId);
            await workspace.save();
        }

        // Set as active workspace and record in user's workspaces
        await User.findByIdAndUpdate(userId, {
            familyId: workspace._id,
            role: alreadyMember ? undefined : 'member',
            $addToSet: {
                workspaces: {
                    workspaceId: workspace._id,
                    role: 'member',
                    joinedAt: new Date(),
                },
            },
        });

        return res.json({
            message: `Successfully joined ${workspace.name}`,
            workspace,
            familyId: workspace._id,
        });
    } catch (error: any) {
        return res.status(500).json({ message: error.message });
    }
};

// @desc    Update workspace details
// @route   PUT /api/workspaces/:id
// @access  Private (Admin only)
export const updateWorkspace = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { name, workspaceType, icon, description } = req.body;
        const userId = (req as any).user?.id || (req as any).user?._id;

        const workspace = await Family.findById(id);
        if (!workspace) {
            return res.status(404).json({ message: 'Workspace not found' });
        }

        if (workspace.createdBy.toString() !== userId.toString()) {
            return res.status(403).json({ message: 'Only workspace admin can update details' });
        }

        if (name) workspace.name = name.trim();
        if (workspaceType) (workspace as any).workspaceType = workspaceType;
        if (icon) (workspace as any).icon = icon;
        if (description !== undefined) (workspace as any).description = description;

        await workspace.save();

        return res.json(workspace);
    } catch (error: any) {
        return res.status(500).json({ message: error.message });
    }
};
