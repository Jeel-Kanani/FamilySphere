"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const documentController_1 = require("../controllers/documentController");
const cloudinary_1 = require("../config/cloudinary");
const router = (0, express_1.Router)();
// POST /api/documents/upload - Upload a new document
router.post('/upload', cloudinary_1.upload.single('file'), documentController_1.uploadDocument);
// GET /api/documents/family/:familyId - Get all documents for a family
router.get('/family/:familyId', documentController_1.getDocuments);
// GET /api/documents/folders/:familyId?category=Shared - Get built-in + custom folders
router.get('/folders/:familyId', documentController_1.getFolders);
// POST /api/documents/folders - Create custom folder
router.post('/folders', documentController_1.createFolder);
// DELETE /api/documents/folders/:folderId - Delete custom folder
router.delete('/folders/:folderId', documentController_1.deleteFolder);
// DELETE /api/documents/:id - Delete a document (move to trash)
router.delete('/:id', documentController_1.deleteDocument);
// GET /api/documents/trash/:familyId - Get trashed documents
router.get('/trash/:familyId', documentController_1.getTrashedDocuments);
// PATCH /api/documents/:id/restore - Restore document from trash
router.patch('/:id/restore', documentController_1.restoreDocument);
// DELETE /api/documents/:id/permanent - Permanently delete document
router.delete('/:id/permanent', documentController_1.permanentlyDeleteDocument);
// PATCH /api/documents/:id/folder - Move document to folder
router.patch('/:id/folder', documentController_1.moveDocumentToFolder);
exports.default = router;
