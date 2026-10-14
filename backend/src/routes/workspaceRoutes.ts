import express from 'express';
import {
    createWorkspace,
    getMyWorkspaces,
    switchWorkspace,
    joinWorkspace,
    updateWorkspace,
} from '../controllers/workspaceController';
import { protect } from '../middleware/authMiddleware';

const router = express.Router();

router.use(protect);

router.post('/', createWorkspace);
router.get('/my', getMyWorkspaces);
router.post('/switch/:id', switchWorkspace);
router.post('/join', joinWorkspace);
router.put('/:id', updateWorkspace);

export default router;
