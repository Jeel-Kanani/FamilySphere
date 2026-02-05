import express from 'express';
import {
    registerUser,
    loginUser,
    getCurrentUser,
    updateProfile,
    logoutUser,
    googleAuth,
    sendEmailOtpController,
    verifyEmailOtpController,
} from '../controllers/authController';
import { protect } from '../middleware/authMiddleware';

const router = express.Router();

router.post('/register', registerUser);
router.post('/send-email-otp', sendEmailOtpController);
router.post('/verify-email-otp', verifyEmailOtpController);
router.post('/login', loginUser);
router.post('/google', googleAuth);
router.post('/logout', protect, logoutUser);
router.get('/me', protect, getCurrentUser);
router.put('/profile', protect, updateProfile);

export default router;
