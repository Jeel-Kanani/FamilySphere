import express from 'express';
import { uploadDocument, getDocuments, deleteDocument } from '../controllers/documentController';

const router = express.Router();

// Vault routes
router.post('/upload', uploadDocument);
router.get('/', getDocuments);
router.delete('/:id', deleteDocument);

export default router;