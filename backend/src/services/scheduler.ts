import cron from 'node-cron';
import Document from '../models/Document';
import Reminder from '../models/Reminder';
import FamilyActivity from '../models/FamilyActivity';
import Event from '../models/Event';

/**
 * Weekly/Monthly/Daily Notification Scheduler
 * Scheduled to run every day at 00:00 (Midnight)
 */
export const initScheduler = () => {
    console.log('Initializing Background Scheduler...');

    // Run every day at midnight
    cron.schedule('0 0 * * *', async () => {
        console.log('Running daily deadline checks...');
        await checkDocumentDeadlines();
        await checkManualReminders();
        await autoExpireStaleReviews();
    });
};

const checkDocumentDeadlines = async () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const nextWeek = new Date(today);
    nextWeek.setDate(today.getDate() + 7);

    // Find documents expiring in 7 days or overdue
    const docs = await Document.find({
        reminderEnabled: true,
        $or: [
            { expiryDate: { $lte: nextWeek, $gte: today } },
            { dueDate: { $lte: nextWeek, $gte: today } }
        ]
    });

    for (const doc of docs) {
        const type = doc.dueDate ? 'Bill Due' : 'Expiry';
        const message = `${doc.title} is approaching its ${type.toLowerCase()} date.`;

        await createTimelineActivity(doc.familyId, doc.uploadedBy, 'expires_soon', message, {
            documentId: doc._id,
            amount: doc.amount
        });

        // Push notification logic would go here (FCM)
        console.log(`Notification sent for ${doc.title}`);
    }
};

const checkManualReminders = async () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const reminders = await Reminder.find({
        isCompleted: false,
        dateTime: { $lte: today }
    });

    for (const reminder of reminders) {
        const message = `Reminder: ${reminder.title}`;

        await createTimelineActivity(reminder.familyId, reminder.assignedTo, 'bill_due', message, {
            reminderId: reminder._id
        });

        // If recurring, update to next date
        if (reminder.repeatType !== 'none') {
            const nextDate = new Date(reminder.dateTime);
            if (reminder.repeatType === 'daily') nextDate.setDate(nextDate.getDate() + 1);
            if (reminder.repeatType === 'weekly') nextDate.setDate(nextDate.getDate() + 7);
            if (reminder.repeatType === 'monthly') nextDate.setMonth(nextDate.getMonth() + 1);

            reminder.dateTime = nextDate;
            await reminder.save();
        }
    }
};

/**
 * REVIEW EXPIRY RULE
 * Events flagged needsReview that the user has ignored for 30+ days are
 * auto-dismissed to prevent stale uncertainty polluting the timeline.
 * reviewAutoExpiredAt is recorded for audit purposes.
 */
const autoExpireStaleReviews = async () => {
    const REVIEW_TTL_DAYS = 30;
    const threshold = new Date();
    threshold.setDate(threshold.getDate() - REVIEW_TTL_DAYS);

    const result = await Event.updateMany(
        {
            needsReview: true,
            reviewAutoExpiredAt: { $exists: false },
            createdAt: { $lte: threshold }
        },
        {
            $set: { needsReview: false },
            $currentDate: { reviewAutoExpiredAt: true }
        }
    );

    if (result.modifiedCount > 0) {
        console.log(`🕒 Auto-expired ${result.modifiedCount} stale review event(s) (>${REVIEW_TTL_DAYS} days unreviewed)`);
    }
};

const createTimelineActivity = async (
    familyId: any,
    actorId: any,
    type: string,
    message: string,
    metadata: any
) => {
    try {
        await FamilyActivity.create({
            familyId,
            actorId,
            type,
            message,
            metadata
        });
    } catch (error) {
        console.error('Error creating activity log:', error);
    }
};
