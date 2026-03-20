import { Router } from 'express';
import * as IntelligenceController from '../controllers/intelligenceController';
import { protect } from '../middleware/authMiddleware';

const router = Router();

router.get('/briefing/:familyId', protect, IntelligenceController.getDailyBriefing);
router.get('/facts/:familyId', protect, IntelligenceController.getRecentFacts);
router.get('/fact/:factId', protect, IntelligenceController.getFactDetails);

export default router;
