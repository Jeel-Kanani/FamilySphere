import FamilyActivity from '../models/FamilyActivity';
import { IDocument } from '../models/Document';

/**
 * NotificationService
 * 
 * Centralized service to handle user notifications, push alerts, 
 * and persistent activity logs.
 */
export class NotificationService {
    /**
     * Send a notification when OCR processing completes.
     */
    static async notifyOcrComplete(document: IDocument): Promise<void> {
        let type: string;
        let message = '';

        if (document.ocrStatus === 'done') {
            type = 'analysis_complete';
            if (document.dueDate || document.expiryDate) {
                const date = document.dueDate || document.expiryDate;
                const formattedDate = date ? new Date(date).toLocaleDateString() : '';
                message = `AI found a deadline in "${document.title}": ${formattedDate}. Reminder added to Timeline.`;
            } else {
                message = `AI analysis complete for "${document.title}". Document details updated.`;
            }
        } else if (document.ocrStatus === 'needs_confirmation') {
            type = 'needs_confirmation';
            const detectedType = document.docType || 'unknown';
            message = `AI is not sure about "${document.title}" (detected as ${detectedType}). Please confirm the document type.`;
        } else {
            type = 'analysis_failed';
            message = `AI could not analyze "${document.title}", but your document is safely stored.`;
        }

        console.log(`[NotificationService] Notification for ${document.uploadedBy}: ${message}`);

        // Persist to activity log so it shows up in "What's New" or Timeline
        try {
            await FamilyActivity.create({
                familyId: document.familyId,
                actorId: document.uploadedBy,
                type: type,
                message: message,
                metadata: {
                    documentId: document._id,
                    docType: document.docType,
                    status: document.ocrStatus
                }
            });
            console.log(`[NotificationService] Activity log created for doc: ${document._id}`);
        } catch (err: any) {
            console.error(`[NotificationService] Failed to create activity log: ${err.message}`);
        }

        // TODO: Integrate Firebase Cloud Messaging (FCM) here for real push notifications
        // await FCMService.send(...)
    }
}
