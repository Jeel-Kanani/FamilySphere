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

export default router;
