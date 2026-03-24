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
    uploadProfilePicture,
} from '../controllers/authController';
import { protect } from '../middleware/authMiddleware';
import { upload } from '../config/cloudinary';

const router = express.Router();

router.post('/register', registerUser);
router.post('/send-email-otp', sendEmailOtpController);
router.post('/verify-email-otp', verifyEmailOtpController);
router.post('/login', loginUser);
router.post('/google', googleAuth);
router.post('/logout', protect, logoutUser);
router.get('/me', protect, getCurrentUser);
router.put('/profile', protect, updateProfile);
router.put('/profile/picture', protect, upload.single('picture'), uploadProfilePicture);

export default router;
