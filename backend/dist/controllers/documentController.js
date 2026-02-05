"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteDocument = exports.getDocuments = exports.uploadDocument = void 0;
const Document_1 = __importDefault(require("../models/Document"));
const cloudinary_1 = require("../config/cloudinary");
const uploadDocument = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { title, category, familyId, uploadedBy } = req.body;
        const file = req.file;
        console.log('--- Upload Document ---');
        console.log('Body:', req.body);
        console.log('File:', file ? { mimetype: file.mimetype, size: file.size } : 'NONE');
        if (!file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }
        const newDocument = new Document_1.default({
            title,
            category,
            fileUrl: file.path,
            fileType: file.mimetype,
            fileSize: file.size,
            cloudinaryId: file.filename,
            familyId,
            uploadedBy,
        });
        yield newDocument.save();
        res.status(201).json(newDocument);
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.uploadDocument = uploadDocument;
const getDocuments = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { familyId } = req.params;
        const { category } = req.query;
        console.log('--- Get Documents ---');
        console.log('Family ID:', familyId);
        console.log('Category Filter:', category);
        const query = { familyId };
        if (category) {
            query.category = category;
        }
        const documents = yield Document_1.default.find(query)
            .sort({ createdAt: -1 })
            .populate('uploadedBy', 'name');
        // Calculate total storage usage for this family
        const allDocs = yield Document_1.default.find({ familyId });
        const totalSize = allDocs.reduce((acc, doc) => acc + (doc.fileSize || 0), 0);
        res.status(200).json({
            documents,
            storageUsed: totalSize,
            storageLimit: 25 * 1024 * 1024 * 1024, // 25 GB limit
        });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.getDocuments = getDocuments;
const deleteDocument = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { id } = req.params;
        const document = yield Document_1.default.findById(id);
        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }
        // Delete from Cloudinary
        yield cloudinary_1.cloudinary.uploader.destroy(document.cloudinaryId);
        // Delete from MongoDB
        yield Document_1.default.findByIdAndDelete(id);
        res.status(200).json({ message: 'Document deleted successfully' });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.deleteDocument = deleteDocument;
