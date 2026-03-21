import { Router } from 'express';
import * as ChatController from '../controllers/chatController';
import { protect } from '../middleware/authMiddleware';

const router = Router();

router.get('/:familyId', protect, ChatController.getMessages);
router.post('/', protect, ChatController.sendMessage);

export default router;
