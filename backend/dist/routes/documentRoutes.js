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
// DELETE /api/documents/:id - Delete a document
router.delete('/:id', documentController_1.deleteDocument);
exports.default = router;
