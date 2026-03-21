import { Request, Response } from 'express';
import ChatMessage from '../models/ChatMessage';
import { emitToFamily } from '../services/socketService';

// @desc    Get family chat messages
// @route   GET /api/chat/:familyId
// @access  Private
export const getMessages = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const messages = await ChatMessage.find({ familyId })
            .sort({ createdAt: -1 })
            .limit(100);
        res.status(200).json(messages.reverse());
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// @desc    Send a new chat message
// @route   POST /api/chat
// @access  Private
export const sendMessage = async (req: Request, res: Response) => {
    try {
        const { familyId, content, type, mediaUrl, metadata } = req.body;
        const message = await ChatMessage.create({
            familyId,
            senderId: (req as any).user._id,
            senderName: (req as any).user.name,
            content,
            type: type || 'text',
            mediaUrl,
            status: 'sent',
            metadata: metadata || {},
        });

        // Real-time broadcast to the family room
        emitToFamily(familyId, 'new_message', message);

        res.status(201).json(message);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};
