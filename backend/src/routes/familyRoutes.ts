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
    getFamilyActivity,
    joinFamilyWithInvite
} from '../controllers/familyController';
import { createInvite, validateInvite } from '../controllers/inviteController';

const router = express.Router();

// Public routes (must come BEFORE parameterized routes to avoid conflicts if needed, but here they are specific)
router.get('/invites/validate', validateInvite);

// All routes below require authentication
router.post('/', protect, createFamily);
router.post('/join', protect, joinFamily);
router.post('/join-invite', protect, joinFamilyWithInvite);
router.get('/:familyId', protect, getFamily);
router.get('/:familyId/members', protect, getFamilyMembers);
router.get('/:familyId/activity', protect, getFamilyActivity);
router.delete('/:familyId/members/:userId', protect, removeFamilyMember);
router.put('/:familyId/members/:userId/role', protect, updateMemberRole);
router.post('/:familyId/members/:userId/transfer-ownership', protect, transferOwnership);
router.put('/:familyId/invite-code', protect, updateInviteCode);
router.post('/:familyId/invites', protect, createInvite);
router.put('/:familyId/settings', protect, updateFamilySettings);
router.post('/:familyId/leave', protect, leaveFamily);

export default router;
