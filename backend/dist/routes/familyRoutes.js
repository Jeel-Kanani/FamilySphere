"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const authMiddleware_1 = require("../middleware/authMiddleware");
const familyController_1 = require("../controllers/familyController");
const inviteController_1 = require("../controllers/inviteController");
const router = express_1.default.Router();
// Public routes (must come BEFORE parameterized routes to avoid conflicts if needed, but here they are specific)
router.get('/invites/validate', inviteController_1.validateInvite);
// All routes below require authentication
router.post('/', authMiddleware_1.protect, familyController_1.createFamily);
router.post('/join', authMiddleware_1.protect, familyController_1.joinFamily);
router.post('/join-invite', authMiddleware_1.protect, familyController_1.joinFamilyWithInvite);
router.get('/:familyId', authMiddleware_1.protect, familyController_1.getFamily);
router.get('/:familyId/members', authMiddleware_1.protect, familyController_1.getFamilyMembers);
router.get('/:familyId/activity', authMiddleware_1.protect, familyController_1.getFamilyActivity);
router.delete('/:familyId/members/:userId', authMiddleware_1.protect, familyController_1.removeFamilyMember);
router.put('/:familyId/members/:userId/role', authMiddleware_1.protect, familyController_1.updateMemberRole);
router.post('/:familyId/members/:userId/transfer-ownership', authMiddleware_1.protect, familyController_1.transferOwnership);
router.put('/:familyId/invite-code', authMiddleware_1.protect, familyController_1.updateInviteCode);
router.post('/:familyId/invites', authMiddleware_1.protect, inviteController_1.createInvite);
router.put('/:familyId/settings', authMiddleware_1.protect, familyController_1.updateFamilySettings);
router.post('/:familyId/leave', authMiddleware_1.protect, familyController_1.leaveFamily);
exports.default = router;
