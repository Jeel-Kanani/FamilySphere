import { Router } from 'express';
import {
    uploadDocument,
    getDocuments,
    deleteDocument,
    getFolders,
    createFolder,
    moveDocumentToFolder,
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

// DELETE /api/documents/:id - Delete a document
router.delete('/:id', deleteDocument);

// PATCH /api/documents/:id/folder - Move document to folder
router.patch('/:id/folder', moveDocumentToFolder);

export default router;
