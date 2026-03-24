import express from 'express';
import { protect, authorize } from '../middleware/authMiddleware';
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
import { createInvite, validateInvite, getFamilyInvites, revokeInvite } from '../controllers/inviteController';
const router = express.Router();

// Public routes
router.get('/invites/validate', validateInvite);

// All routes below require authentication
router.post('/', protect, createFamily);
router.post('/join', protect, joinFamily);
router.post('/join-invite', protect, joinFamilyWithInvite);

router.get('/:familyId', protect, authorize('admin', 'member', 'viewer'), getFamily);
router.get('/:familyId/members', protect, authorize('admin', 'member', 'viewer'), getFamilyMembers);
router.get('/:familyId/activity', protect, authorize('admin', 'member', 'viewer'), getFamilyActivity);

// Admin only
router.delete('/:familyId/members/:userId', protect, authorize('admin'), removeFamilyMember);
router.put('/:familyId/members/:userId/role', protect, authorize('admin', 'member'), updateMemberRole); // Members can invite and manage their invites
router.post('/:familyId/members/:userId/transfer-ownership', protect, authorize('admin'), transferOwnership);
router.put('/:familyId/invite-code', protect, authorize('admin'), updateInviteCode);
router.put('/:familyId/settings', protect, authorize('admin'), updateFamilySettings);

// Admin & Member
router.post('/:familyId/invites', protect, authorize('admin', 'member'), createInvite);
router.get('/:familyId/invites', protect, authorize('admin', 'member'), getFamilyInvites);
router.delete('/:familyId/invites/:inviteId', protect, authorize('admin', 'member'), revokeInvite);

router.post('/:familyId/leave', protect, authorize('admin', 'member', 'viewer'), leaveFamily);

export default router;
