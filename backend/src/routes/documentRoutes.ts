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
} from '../controllers/documentController';
import { upload } from '../config/cloudinary';

const router = Router();

// POST /api/documents/upload - Upload a new document
router.post('/upload', upload.single('file'), uploadDocument);

// GET /api/documents/family/:familyId - Get all documents for a family
router.get('/family/:familyId', getDocuments);

// GET /api/documents/folders/:familyId?category=Shared - Get built-in + custom folders
router.get('/folders/:familyId', getFolders);

// POST /api/documents/folders - Create custom folder
router.post('/folders', createFolder);

// DELETE /api/documents/folders/:folderId - Delete custom folder
router.delete('/folders/:folderId', deleteFolder);

// DELETE /api/documents/:id - Delete a document (move to trash)
router.delete('/:id', deleteDocument);

// GET /api/documents/trash/:familyId - Get trashed documents
router.get('/trash/:familyId', getTrashedDocuments);

// PATCH /api/documents/:id/restore - Restore document from trash
router.patch('/:id/restore', restoreDocument);

// DELETE /api/documents/:id/permanent - Permanently delete document
router.delete('/:id/permanent', permanentlyDeleteDocument);

// PATCH /api/documents/:id/folder - Move document to folder
router.patch('/:id/folder', moveDocumentToFolder);

// GET /api/documents/:id/ocr-status - Poll OCR job progress (Phase 4)
router.get('/:id/ocr-status', getOcrStatus);

// GET /api/documents/:id/intelligence - Get full DocumentIntelligence (tags, entities, importance)
router.get('/:id/intelligence', getDocumentIntelligence);

// PATCH /api/documents/:id/confirm-type - User confirms or corrects AI-detected doc type
router.patch('/:id/confirm-type', confirmDocumentType);

// PATCH /api/documents/:id/confirm-intelligence - User reviews Tier 2/3 suggested events
// Body: { doc_type?, confirmed_events: [{index, accepted, edited_title?, edited_date?}], manual_entities? }
router.patch('/:id/confirm-intelligence', confirmIntelligence);

// POST /api/documents/requeue-stuck - Re-queue all pending/processing stuck docs
router.post('/requeue-stuck', requeueStuckDocuments);

export default router;
