import { Router } from 'express';
import {
    uploadDocument,
    getDocuments,
    deleteDocument,
    getFolders,
    createFolder,
    deleteFolder,
    moveDocumentToFolder,
    getTrashedDocuments,
    restoreDocument,
    permanentlyDeleteDocument,
    getOcrStatus,
    requeueStuckDocuments,
    getDocumentIntelligence,
    confirmDocumentType,
    confirmIntelligence,
    reprocessOcr,
} from '../controllers/documentController';
import { upload } from '../config/cloudinary';
import { protect, authorize } from '../middleware/authMiddleware';

const router = Router();

router.use(protect);

// All routes require authentication (already handled by router.use(protect))

// POST /api/documents/upload - Upload a new document (Admin & Member)
router.post('/upload', authorize('admin', 'member'), upload.single('file'), uploadDocument);

// GET /api/documents/family/:familyId - Get all documents for a family (All roles)
router.get('/family/:familyId', authorize('admin', 'member', 'viewer'), getDocuments);

// GET /api/documents/folders/:familyId - Get folders (All roles)
router.get('/folders/:familyId', authorize('admin', 'member', 'viewer'), getFolders);

// POST /api/documents/folders - Create custom folder (Admin & Member)
router.post('/folders', authorize('admin', 'member'), createFolder);

// DELETE /api/documents/folders/:folderId - Delete custom folder (Admin & Member)
router.delete('/folders/:folderId', authorize('admin', 'member'), deleteFolder);

// DELETE /api/documents/:id - Delete a document (Admin & Member)
router.delete('/:id', authorize('admin', 'member'), deleteDocument);

// GET /api/documents/trash/:familyId - Get trashed documents (All roles)
router.get('/trash/:familyId', authorize('admin', 'member', 'viewer'), getTrashedDocuments);

// PATCH /api/documents/:id/restore - Restore document from trash (Admin & Member)
router.patch('/:id/restore', authorize('admin', 'member'), restoreDocument);

// DELETE /api/documents/:id/permanent - Permanently delete document (Admin Only)
router.delete('/:id/permanent', authorize('admin'), permanentlyDeleteDocument);

// PATCH /api/documents/:id/folder - Move document to folder (Admin & Member)
router.patch('/:id/folder', authorize('admin', 'member'), moveDocumentToFolder);

// GET /api/documents/:id/ocr-status - Poll OCR status (All roles)
router.get('/:id/ocr-status', authorize('admin', 'member', 'viewer'), getOcrStatus);

// GET /api/documents/:id/intelligence - Get full DocumentIntelligence (All roles)
router.get('/:id/intelligence', authorize('admin', 'member', 'viewer'), getDocumentIntelligence);

// PATCH /api/documents/:id/confirm-type - User confirms metadata (Admin & Member)
router.patch('/:id/confirm-type', authorize('admin', 'member'), confirmDocumentType);

// PATCH /api/documents/:id/confirm-intelligence (Admin & Member)
router.patch('/:id/confirm-intelligence', authorize('admin', 'member'), confirmIntelligence);

// System/Admin only management
router.post('/requeue-stuck', authorize('admin'), requeueStuckDocuments);
router.post('/:id/reprocess', authorize('admin'), reprocessOcr);

export default router;
