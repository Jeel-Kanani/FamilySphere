import express from 'express';
import { protect } from '../middleware/authMiddleware';
import {
    createFamily,
    joinFamily,
    getFamily,
    getFamilyMembers,
    leaveFamily
} from '../controllers/familyController';

const router = express.Router();

// All routes require authentication
router.post('/', protect, createFamily);
router.post('/join', protect, joinFamily);
router.get('/:familyId', protect, getFamily);
router.get('/:familyId/members', protect, getFamilyMembers);
router.post('/:familyId/leave', protect, leaveFamily);

export default router;
