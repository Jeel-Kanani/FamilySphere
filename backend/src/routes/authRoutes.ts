import express from 'express';
import { registerUser, loginUser, getCurrentUser, updateProfile } from '../controllers/authController';
import { protect } from '../middleware/authMiddleware';

const router = express.Router();

router.post('/register', registerUser);
router.post('/login', loginUser);
router.get('/me', protect, getCurrentUser);
router.put('/profile', protect, updateProfile);

export default router;
