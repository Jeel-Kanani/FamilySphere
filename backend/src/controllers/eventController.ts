import { Request, Response } from 'express';
import Event, { EventStatus } from '../models/Event';
import mongoose from 'mongoose';

/**
 * GET /api/events/future
 * Fetches events in the future relative to a cursor (date).
 * Used for scrolling UP in the timeline.
 */
export const getFutureEvents = async (req: Request, res: Response) => {
    try {
        const { cursor, limit = 20 } = req.query;
        const familyId = (req as any).user.familyId; // Assuming auth middleware attaches user/family

        const query: any = {
            familyId,
            startDate: cursor
                ? { $gt: new Date(cursor as string) }   // paginating: exclude the cursor event
                : { $gte: new Date() }                  // initial load: from now onwards
        };

        const events = await Event.find(query)
            .sort({ startDate: 1 }) // Nearest future first
            .limit(Number(limit))
            .lean();

        res.status(200).json({
            success: true,
            data: events,
            nextCursor: events.length > 0 ? events[events.length - 1].startDate : null
        });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * GET /api/events/past
 * Fetches events in the past relative to a cursor (date).
 * Used for scrolling DOWN in the timeline.
 */
export const getPastEvents = async (req: Request, res: Response) => {
    try {
        const { cursor, limit = 20 } = req.query;
        const familyId = (req as any).user.familyId;

        const query: any = {
            familyId,
            startDate: { $lt: cursor ? new Date(cursor as string) : new Date() }
        };

        const events = await Event.find(query)
            .sort({ startDate: -1 }) // Newest past first
            .limit(Number(limit))
            .lean();

        res.status(200).json({
            success: true,
            data: events,
            nextCursor: events.length > 0 ? events[events.length - 1].startDate : null
        });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * POST /api/events
 * Manually create a new event.
 */
export const createManualEvent = async (req: Request, res: Response) => {
    try {
        const { type, title, description, startDate, priority, relatedDocumentId } = req.body;
        const userId = (req as any).user._id;
        const familyId = (req as any).user.familyId;

        const newEvent = new Event({
            userId,
            familyId,
            type,
            title,
            description,
            startDate,
            priority,
            relatedDocumentId,
            source: 'manual'
        });

        await newEvent.save();

        res.status(201).json({
            success: true,
            data: newEvent
        });
    } catch (error: any) {
        res.status(400).json({ success: false, message: error.message });
    }
};

/**
 * PATCH /api/events/:id
 * User manually edits an event (title, date, description, etc.).
 *
 * SYSTEM INTEGRITY: Sets isUserModified = true so future OCR re-runs
 * cannot silently override the user's correction.
 */
export const updateEvent = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const familyId = (req as any).user.familyId;

        if (!mongoose.Types.ObjectId.isValid(id as string)) {
            return res.status(400).json({ success: false, message: 'Invalid event ID' });
        }

        const allowedFields = ['title', 'description', 'startDate', 'endDate', 'priority', 'status', 'type'];
        const updates: Record<string, any> = { isUserModified: true };

        for (const field of allowedFields) {
            if (req.body[field] !== undefined) updates[field] = req.body[field];
        }

        const event = await Event.findOneAndUpdate(
            { _id: id, familyId },
            { $set: updates },
            { new: true, runValidators: true }
        );

        if (!event) {
            return res.status(404).json({ success: false, message: 'Event not found' });
        }

        res.status(200).json({ success: true, data: event });
    } catch (error: any) {
        res.status(400).json({ success: false, message: error.message });
    }
};

/**
 * PATCH /api/events/:id/dismiss-review
 * User acknowledges and dismisses the "needs review" flag on an AI-generated event.
 * Can optionally accept the OCR-extracted date or provide a correction.
 */
export const dismissReview = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const familyId = (req as any).user.familyId;
        const { correctedDate } = req.body; // optional user correction

        if (!mongoose.Types.ObjectId.isValid(id as string)) {
            return res.status(400).json({ success: false, message: 'Invalid event ID' });
        }

        const updates: Record<string, any> = { needsReview: false };

        if (correctedDate) {
            // User is providing their own date — lock it from future OCR overrides
            updates.startDate = new Date(correctedDate);
            updates.isUserModified = true;
        }

        const event = await Event.findOneAndUpdate(
            { _id: id, familyId },
            { $set: updates },
            { new: true }
        );

        if (!event) {
            return res.status(404).json({ success: false, message: 'Event not found' });
        }

        res.status(200).json({ success: true, data: event });
    } catch (error: any) {
        res.status(400).json({ success: false, message: error.message });
    }
};

/**
 * DELETE /api/events/:id
 * Permanently delete an event.
 */
export const deleteEvent = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const familyId = (req as any).user.familyId;

        if (!mongoose.Types.ObjectId.isValid(id as string)) {
            return res.status(400).json({ success: false, message: 'Invalid event ID' });
        }

        const event = await Event.findOneAndDelete({ _id: id, familyId });

        if (!event) {
            return res.status(404).json({ success: false, message: 'Event not found' });
        }

        res.status(200).json({ success: true, message: 'Event deleted' });
    } catch (error: any) {
        res.status(400).json({ success: false, message: error.message });
    }
};
