import { Router } from 'express';
import * as HubController from '../controllers/hubController';
import { protect } from '../middleware/authMiddleware';

const router = Router();

router.get('/feed/:familyId', protect, HubController.getFeed);
router.post('/feed', protect, HubController.createPost);
router.post('/feed/:postId/like', protect, HubController.toggleLike);
router.get('/activity/:familyId', protect, HubController.getActivities);

export default router;
