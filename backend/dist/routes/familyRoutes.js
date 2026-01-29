"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const authMiddleware_1 = require("../middleware/authMiddleware");
const familyController_1 = require("../controllers/familyController");
const router = express_1.default.Router();
// All routes require authentication
router.post('/', authMiddleware_1.protect, familyController_1.createFamily);
router.post('/join', authMiddleware_1.protect, familyController_1.joinFamily);
router.get('/:familyId', authMiddleware_1.protect, familyController_1.getFamily);
router.get('/:familyId/members', authMiddleware_1.protect, familyController_1.getFamilyMembers);
router.post('/:familyId/leave', authMiddleware_1.protect, familyController_1.leaveFamily);
exports.default = router;
