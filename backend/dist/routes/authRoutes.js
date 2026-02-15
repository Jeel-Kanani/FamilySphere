"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const authController_1 = require("../controllers/authController");
const authMiddleware_1 = require("../middleware/authMiddleware");
const router = express_1.default.Router();
router.post('/register', authController_1.registerUser);
router.post('/send-email-otp', authController_1.sendEmailOtpController);
router.post('/verify-email-otp', authController_1.verifyEmailOtpController);
router.post('/login', authController_1.loginUser);
router.post('/google', authController_1.googleAuth);
router.post('/logout', authMiddleware_1.protect, authController_1.logoutUser);
router.get('/me', authMiddleware_1.protect, authController_1.getCurrentUser);
router.put('/profile', authMiddleware_1.protect, authController_1.updateProfile);
exports.default = router;
