import { Router } from 'express';
import { uploadDocument, getDocuments, deleteDocument } from '../controllers/documentController';
import { upload } from '../config/cloudinary';

const router = Router();

// POST /api/documents/upload - Upload a new document
router.post('/upload', upload.single('file'), uploadDocument);

// GET /api/documents/family/:familyId - Get all documents for a family
router.get('/family/:familyId', getDocuments);

// DELETE /api/documents/:id - Delete a document
router.delete('/:id', deleteDocument);

export default router;
