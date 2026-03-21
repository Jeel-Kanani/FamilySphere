import { Request, Response } from 'express';
import Post from '../models/Post';
import FamilyActivity from '../models/FamilyActivity';
import { emitToFamily } from '../services/socketService';

// @desc    Get family feed posts
// @route   GET /api/hub/feed/:familyId
// @access  Private
export const getFeed = async (req: Request, res: Response) => {
    try {
        const posts = await Post.find({ familyId: req.params.familyId })
            .sort({ createdAt: -1 })
            .limit(50);
        res.status(200).json(posts);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// @desc    Create a new post
// @route   POST /api/hub/feed
// @access  Private
export const createPost = async (req: Request, res: Response) => {
    try {
        const { familyId, content, mediaUrls, type } = req.body;
        const post = await Post.create({
            familyId,
            creatorId: (req as any).user._id,
            content,
            mediaUrls: mediaUrls || [],
            type,
        });

        // Broadcast new post to family room
        emitToFamily(familyId, 'new_post', post);

        // Log activity
        const activity = await FamilyActivity.create({
            familyId,
            actorId: (req as any).user._id,
            actorName: (req as any).user.name,
            type: 'new_post',
            message: `shared a new ${type}`,
            metadata: { postId: post._id },
        });

        // Broadcast activity event
        emitToFamily(familyId, 'new_activity', activity);

        res.status(201).json(post);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// @desc    Like/Unlike a post
// @route   POST /api/hub/feed/:postId/like
// @access  Private
export const toggleLike = async (req: Request, res: Response) => {
    try {
        const post = await Post.findById(req.params.postId);
        if (!post) return res.status(404).json({ message: 'Post not found' });

        const userId = (req as any).user._id;
        const index = post.likes.indexOf(userId);

        if (index === -1) {
            post.likes.push(userId);
        } else {
            post.likes.splice(index, 1);
        }

        await post.save();
        res.status(200).json(post);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// @desc    Get family activity timeline
// @route   GET /api/hub/activity/:familyId
// @access  Private
export const getActivities = async (req: Request, res: Response) => {
    try {
        const activities = await FamilyActivity.find({ familyId: req.params.familyId })
            .sort({ createdAt: -1 })
            .limit(30);
        res.status(200).json(activities);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};
