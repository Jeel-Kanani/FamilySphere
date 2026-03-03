import express from 'express';
import { getFutureEvents, getPastEvents, createManualEvent, updateEvent, dismissReview, deleteEvent } from '../controllers/eventController';
import { protect } from '../middleware/authMiddleware'; // Assuming standard auth middleware

const router = express.Router();

// All timeline routes are protected
router.use(protect);

router.get('/future', getFutureEvents);
router.get('/past', getPastEvents);
router.post('/', createManualEvent);

// ─── System Integrity & Review ────────────────────────────────────────────
// PATCH marks isUserModified=true — OCR will not override this event again
router.patch('/:id', updateEvent);
// Dismiss a needsReview flag; optionally accept a user-corrected date
router.patch('/:id/dismiss-review', dismissReview);
// DELETE permanently removes an event
router.delete('/:id', deleteEvent);

export default router;
