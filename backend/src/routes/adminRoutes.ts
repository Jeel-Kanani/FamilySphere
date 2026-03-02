import { Router } from 'express';
import { getEngineDashboard, adminRequeueStuck, getDocumentFullDetail } from '../controllers/adminController';

const router = Router();

// GET  /api/admin/engine-dashboard — full pipeline status for all docs
router.get('/engine-dashboard', getEngineDashboard);

// POST /api/admin/requeue-stuck — re-queue pending/processing/failed docs
router.post('/requeue-stuck', adminRequeueStuck);

// GET  /api/admin/doc/:id/full — full detail (doc + intel + events) for one document
router.get('/doc/:id/full', getDocumentFullDetail);

export default router;
