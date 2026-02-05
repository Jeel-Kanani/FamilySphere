import express from 'express';
import { protect } from '../middleware/authMiddleware';
import {
    createFamily,
    joinFamily,
    getFamily,
    getFamilyMembers,
    removeFamilyMember,
    updateMemberRole,
    transferOwnership,
    leaveFamily,
    updateInviteCode,
    updateFamilySettings,
    getFamilyActivity
} from '../controllers/familyController';

const router = express.Router();

// All routes require authentication
router.post('/', protect, createFamily);
router.post('/join', protect, joinFamily);
router.get('/:familyId', protect, getFamily);
router.get('/:familyId/members', protect, getFamilyMembers);
router.get('/:familyId/activity', protect, getFamilyActivity);
router.delete('/:familyId/members/:userId', protect, removeFamilyMember);
router.put('/:familyId/members/:userId/role', protect, updateMemberRole);
router.post('/:familyId/members/:userId/transfer-ownership', protect, transferOwnership);
router.put('/:familyId/invite-code', protect, updateInviteCode);
router.put('/:familyId/settings', protect, updateFamilySettings);
router.post('/:familyId/leave', protect, leaveFamily);

export default router;
