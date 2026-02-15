"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
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
exports.permanentlyDeleteDocument = exports.restoreDocument = exports.getTrashedDocuments = exports.deleteFolder = exports.moveDocumentToFolder = exports.createFolder = exports.getFolders = exports.deleteDocument = exports.getDocuments = exports.uploadDocument = void 0;
const Document_1 = __importDefault(require("../models/Document"));
const VaultFolder_1 = __importDefault(require("../models/VaultFolder"));
const cloudinary_1 = require("../config/cloudinary");
const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const BUILT_IN_FOLDERS = {
    Shared: [
        'Property Deed',
        'Medical',
        'Insurance',
        'Vehicle',
        'Finance & Tax',
        'Legal',
        'Education',
        'Household Bills',
        'Family Identity',
    ],
    Personal: [
        'Study & Learning',
        'Career Documents',
        'Business',
        'Portfolio',
        'Personal Certificates',
        'Creative Work',
        'Travel',
        'Misc Personal',
    ],
    Private: [
        'Passwords',
        'Confidential Notes',
        'Legal Contracts',
        'Bank Accounts',
        'Identity Secrets',
        'Recovery Keys',
        'Private Finance',
        'Critical Credentials',
    ],
};
const canonicalCategory = (value) => {
    const normalized = (value || '').trim().toLowerCase();
    if (normalized === 'family' || normalized === 'family vault' || normalized === 'shared' || normalized === 'individual')
        return 'Shared';
    if (normalized === 'personal')
        return 'Personal';
    if (normalized === 'private' || normalized === 'private vault')
        return 'Private';
    return (value === null || value === void 0 ? void 0 : value.trim()) || 'Shared';
};
const uploadDocument = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { title, category, familyId, uploadedBy, folder, memberId } = req.body;
        const file = req.file;
        console.log('--- Upload Document ---');
        console.log('Body:', req.body);
        console.log('File:', file ? { mimetype: file.mimetype, size: file.size } : 'NONE');
        if (!file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }
        const originalName = (file.originalname || '').toString().toLowerCase();
        const mimeType = (file.mimetype || '').toString().toLowerCase();
        const uploadPath = (file.path || '').toString().toLowerCase();
        const isPdf = mimeType.includes('pdf') || originalName.endsWith('.pdf') || uploadPath.endsWith('.pdf');
        const newDocument = new Document_1.default({
            title,
            category: canonicalCategory(category),
            folder: (folder || 'General').trim() || 'General',
            memberId: memberId || undefined,
            fileUrl: file.path,
            fileType: isPdf ? 'application/pdf' : file.mimetype,
            fileSize: file.size,
            cloudinaryId: file.filename,
            familyId,
            uploadedBy,
        });
        yield newDocument.save();
        // Update family storage
        const Family = (yield Promise.resolve().then(() => __importStar(require('../models/Family')))).default;
        yield Family.findByIdAndUpdate(familyId, {
            $inc: { storageUsed: file.size || 0 }
        });
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
        const { category, folder, memberId } = req.query;
        console.log('--- Get Documents ---');
        console.log('Family ID:', familyId);
        console.log('Category Filter:', category);
        const query = { familyId, deleted: false };
        const normalizedCategory = typeof category === 'string' ? category.trim() : '';
        if (normalizedCategory) {
            const categoryValue = canonicalCategory(normalizedCategory);
            // Backward compatibility: old Individual data is treated as Shared.
            if (categoryValue === 'Shared') {
                query.$or = [
                    { category: { $regex: '^Shared$', $options: 'i' } },
                    { category: { $regex: '^Individual$', $options: 'i' } },
                ];
            }
            else {
                query.category = {
                    $regex: `^${escapeRegex(categoryValue)}$`,
                    $options: 'i',
                };
            }
        }
        const normalizedFolder = typeof folder === 'string' ? folder.trim() : '';
        if (normalizedFolder) {
            query.folder = {
                $regex: `^${escapeRegex(normalizedFolder)}$`,
                $options: 'i',
            };
        }
        const normalizedMemberId = typeof memberId === 'string' ? memberId.trim() : '';
        if (normalizedMemberId) {
            const memberScope = [
                { memberId: normalizedMemberId },
                { memberId: { $exists: false }, uploadedBy: normalizedMemberId },
            ];
            if (query.$or) {
                query.$and = [{ $or: query.$or }, { $or: memberScope }];
                delete query.$or;
            }
            else {
                query.$or = memberScope;
            }
        }
        const documents = yield Document_1.default.find(query)
            .sort({ createdAt: -1 })
            .populate('uploadedBy', 'name');
        // Get storage from family model (cached value)
        const Family = (yield Promise.resolve().then(() => __importStar(require('../models/Family')))).default;
        const family = yield Family.findById(familyId);
        let storageUsed = (family === null || family === void 0 ? void 0 : family.storageUsed) || 0;
        const storageLimit = (family === null || family === void 0 ? void 0 : family.storageLimit) || (25 * 1024 * 1024 * 1024);
        // Periodically recalculate storage to fix any discrepancies (every 10th request)
        if (Math.random() < 0.1) {
            const allDocs = yield Document_1.default.find({ familyId, deleted: false });
            const actualSize = allDocs.reduce((acc, doc) => acc + (doc.fileSize || 0), 0);
            if (Math.abs(actualSize - storageUsed) > 1024) { // Update if difference > 1KB
                storageUsed = actualSize;
                yield Family.findByIdAndUpdate(familyId, { storageUsed: actualSize });
            }
        }
        res.status(200).json({
            documents,
            storageUsed,
            storageLimit,
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
        // Update family storage
        const Family = (yield Promise.resolve().then(() => __importStar(require('../models/Family')))).default;
        yield Family.findByIdAndUpdate(document.familyId, {
            $inc: { storageUsed: -(document.fileSize || 0) }
        });
        // Soft delete - mark as deleted
        document.deleted = true;
        document.deletedAt = new Date();
        yield document.save();
        res.status(200).json({ message: 'Document moved to trash successfully' });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.deleteDocument = deleteDocument;
const getFolders = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        const { familyId } = req.params;
        const category = canonicalCategory(typeof req.query.category === 'string' ? req.query.category : undefined);
        const memberId = typeof req.query.memberId === 'string' ? req.query.memberId.trim() : '';
        const folderQuery = { familyId };
        if (category === 'Shared') {
            folderQuery.$or = [
                { category: 'Shared' },
                { category: 'Individual' }, // legacy
            ];
        }
        else {
            folderQuery.category = category;
        }
        if (memberId) {
            if (category === 'Shared') {
                folderQuery.$and = [
                    { $or: (_a = folderQuery.$or) !== null && _a !== void 0 ? _a : [{ category: category }] },
                    { $or: [{ memberId }, { memberId: { $exists: false } }] },
                ];
                delete folderQuery.$or;
            }
            else {
                folderQuery.memberId = memberId;
            }
        }
        else {
            folderQuery.memberId = { $exists: false };
        }
        const customFolders = yield VaultFolder_1.default.find(folderQuery)
            .sort({ createdAt: 1 })
            .lean();
        // Get deleted built-in folders markers
        const deletedBuiltInQuery = {
            familyId,
            deleted: true,
        };
        if (category === 'Shared') {
            deletedBuiltInQuery.$or = [
                { category: 'Shared' },
                { category: 'Individual' },
            ];
        }
        else {
            deletedBuiltInQuery.category = category;
        }
        if (memberId) {
            deletedBuiltInQuery.memberId = memberId;
        }
        else {
            deletedBuiltInQuery.memberId = { $exists: false };
        }
        const deletedBuiltIns = yield VaultFolder_1.default.find(deletedBuiltInQuery).lean();
        const deletedBuiltInNames = new Set(deletedBuiltIns.map((f) => f.name));
        const documentQuery = { familyId };
        if (category === 'Shared') {
            documentQuery.$or = [
                { category: 'Shared' },
                { category: 'Individual' }, // legacy
            ];
        }
        else {
            documentQuery.category = category;
        }
        if (memberId) {
            const memberScope = [
                { memberId },
                { memberId: { $exists: false }, uploadedBy: memberId },
            ];
            if (documentQuery.$or) {
                documentQuery.$and = [{ $or: documentQuery.$or }, { $or: memberScope }];
                delete documentQuery.$or;
            }
            else {
                documentQuery.$or = memberScope;
            }
        }
        const documentFolders = yield Document_1.default.distinct('folder', documentQuery);
        const merged = new Set([
            ...(BUILT_IN_FOLDERS[category] || []).filter(name => !deletedBuiltInNames.has(name)),
            ...customFolders.map((f) => (f.name || '').trim()).filter((name) => {
                const folder = customFolders.find((cf) => cf.name === name);
                return name && !(folder === null || folder === void 0 ? void 0 : folder.deleted);
            }),
            ...documentFolders.map((f) => (f || '').toString().trim()).filter(Boolean),
        ]);
        // Build folder details array
        const folderDetails = Array.from(merged).map(name => {
            var _a;
            const builtIn = (BUILT_IN_FOLDERS[category] || []).includes(name);
            const custom = customFolders.find((f) => f.name === name);
            return {
                name,
                isBuiltIn: builtIn,
                isCustom: !!custom,
                folderId: (_a = custom === null || custom === void 0 ? void 0 : custom._id) === null || _a === void 0 ? void 0 : _a.toString(),
                isSystem: false, // Allow all folders to be deletable
            };
        });
        res.status(200).json({
            category,
            folders: Array.from(merged), // Keep for backward compatibility
            folderDetails, // New detailed format
        });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.getFolders = getFolders;
const createFolder = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { familyId, category, name, memberId } = req.body;
        const normalizedName = (name || '').trim();
        if (!familyId || !category || !normalizedName) {
            return res.status(400).json({ message: 'familyId, category and name are required' });
        }
        const categoryValue = canonicalCategory(category);
        const existing = yield VaultFolder_1.default.findOne({
            familyId,
            category: categoryValue,
            memberId: memberId || undefined,
            name: {
                $regex: `^${escapeRegex(normalizedName)}$`,
                $options: 'i',
            },
        });
        if (existing) {
            return res.status(409).json({ message: 'Folder already exists' });
        }
        const folder = yield VaultFolder_1.default.create({
            familyId,
            category: categoryValue,
            memberId: memberId || undefined,
            name: normalizedName,
            isSystem: false,
        });
        res.status(201).json(folder);
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.createFolder = createFolder;
const moveDocumentToFolder = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { id } = req.params;
        const { folder, memberId } = req.body;
        const normalizedFolder = (folder || '').trim();
        if (!normalizedFolder) {
            return res.status(400).json({ message: 'folder is required' });
        }
        const updated = yield Document_1.default.findByIdAndUpdate(id, Object.assign({ folder: normalizedFolder }, (memberId ? { memberId } : {})), { new: true });
        if (!updated) {
            return res.status(404).json({ message: 'Document not found' });
        }
        res.status(200).json(updated);
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.moveDocumentToFolder = moveDocumentToFolder;
const deleteFolder = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { folderId } = req.params;
        const { folderName, familyId, category, memberId } = req.body;
        // Try to find existing folder
        let folder = folderId ? yield VaultFolder_1.default.findById(folderId) : null;
        // If no folder found and folderName provided, this might be a built-in folder
        if (!folder && folderName && familyId && category) {
            const categoryValue = canonicalCategory(category);
            const builtInFolders = BUILT_IN_FOLDERS[categoryValue] || [];
            if (builtInFolders.includes(folderName)) {
                // Create a deleted marker for built-in folder
                folder = yield VaultFolder_1.default.create({
                    familyId,
                    category: categoryValue,
                    memberId: memberId || undefined,
                    name: folderName,
                    isSystem: false,
                    deleted: true,
                });
                return res.status(200).json({ message: 'Built-in folder hidden successfully' });
            }
            return res.status(404).json({ message: 'Folder not found' });
        }
        if (!folder) {
            return res.status(404).json({ message: 'Folder not found' });
        }
        // Check if folder contains any documents
        const documentsInFolder = yield Document_1.default.countDocuments(Object.assign({ familyId: folder.familyId, category: folder.category, folder: folder.name }, (folder.memberId ? { memberId: folder.memberId } : {})));
        if (documentsInFolder > 0) {
            return res.status(400).json({
                message: 'Cannot delete folder with documents. Please move or delete all documents first.',
                documentCount: documentsInFolder
            });
        }
        // Mark as deleted instead of actually deleting (for potential recovery)
        yield VaultFolder_1.default.findByIdAndUpdate(folder._id, { deleted: true });
        res.status(200).json({ message: 'Folder deleted successfully' });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.deleteFolder = deleteFolder;
const getTrashedDocuments = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { familyId } = req.params;
        const documents = yield Document_1.default.find({
            familyId,
            deleted: true
        })
            .sort({ deletedAt: -1 })
            .populate('uploadedBy', 'name');
        res.status(200).json({ documents });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.getTrashedDocuments = getTrashedDocuments;
const restoreDocument = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { id } = req.params;
        const document = yield Document_1.default.findById(id);
        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }
        if (!document.deleted) {
            return res.status(400).json({ message: 'Document is not in trash' });
        }
        // Restore document
        document.deleted = false;
        document.deletedAt = undefined;
        yield document.save();
        res.status(200).json({ message: 'Document restored successfully', document });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.restoreDocument = restoreDocument;
const permanentlyDeleteDocument = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const { id } = req.params;
        const document = yield Document_1.default.findById(id);
        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }
        // Delete from Cloudinary
        yield cloudinary_1.cloudinary.uploader.destroy(document.cloudinaryId);
        // Permanently delete from MongoDB
        yield Document_1.default.findByIdAndDelete(id);
        res.status(200).json({ message: 'Document permanently deleted' });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.permanentlyDeleteDocument = permanentlyDeleteDocument;
