import { Request, Response } from 'express';
import Document from '../models/Document';
import VaultFolder from '../models/VaultFolder';
import { cloudinary } from '../config/cloudinary';

const escapeRegex = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const BUILT_IN_FOLDERS: Record<string, string[]> = {
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

const canonicalCategory = (value: string | undefined): string => {
    const normalized = (value || '').trim().toLowerCase();
    if (normalized === 'family' || normalized === 'family vault' || normalized === 'shared' || normalized === 'individual') return 'Shared';
    if (normalized === 'personal') return 'Personal';
    if (normalized === 'private' || normalized === 'private vault') return 'Private';
    return value?.trim() || 'Shared';
};

export const uploadDocument = async (req: Request, res: Response) => {
    try {
        const { title, category, familyId, uploadedBy, folder, memberId } = req.body;
        const file = req.file as any;

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

        const newDocument = new Document({
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

        await newDocument.save();

        // Update family storage
        const Family = (await import('../models/Family')).default;
        await Family.findByIdAndUpdate(familyId, {
            $inc: { storageUsed: file.size || 0 }
        });

        res.status(201).json(newDocument);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const getDocuments = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const { category, folder, memberId } = req.query;

        console.log('--- Get Documents ---');
        console.log('Family ID:', familyId);
        console.log('Category Filter:', category);

        const query: any = { familyId, deleted: false };
        const normalizedCategory = typeof category === 'string' ? category.trim() : '';
        if (normalizedCategory) {
            const categoryValue = canonicalCategory(normalizedCategory);
            // Backward compatibility: old Individual data is treated as Shared.
            if (categoryValue === 'Shared') {
                query.$or = [
                    { category: { $regex: '^Shared$', $options: 'i' } },
                    { category: { $regex: '^Individual$', $options: 'i' } },
                ];
            } else {
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
            } else {
                query.$or = memberScope;
            }
        }

        const documents = await Document.find(query)
            .sort({ createdAt: -1 })
            .populate('uploadedBy', 'name');

        // Get storage from family model (cached value)
        const Family = (await import('../models/Family')).default;
        const family = await Family.findById(familyId);
        
        let storageUsed = family?.storageUsed || 0;
        const storageLimit = family?.storageLimit || (25 * 1024 * 1024 * 1024);

        // Periodically recalculate storage to fix any discrepancies (every 10th request)
        if (Math.random() < 0.1) {
            const allDocs = await Document.find({ familyId, deleted: false });
            const actualSize = allDocs.reduce((acc, doc) => acc + (doc.fileSize || 0), 0);
            if (Math.abs(actualSize - storageUsed) > 1024) { // Update if difference > 1KB
                storageUsed = actualSize;
                await Family.findByIdAndUpdate(familyId, { storageUsed: actualSize });
            }
        }

        res.status(200).json({
            documents,
            storageUsed,
            storageLimit,
        });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const deleteDocument = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const document = await Document.findById(id);

        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }

        // Update family storage
        const Family = (await import('../models/Family')).default;
        await Family.findByIdAndUpdate(document.familyId, {
            $inc: { storageUsed: -(document.fileSize || 0) }
        });

        // Soft delete - mark as deleted
        document.deleted = true;
        document.deletedAt = new Date();
        await document.save();

        res.status(200).json({ message: 'Document moved to trash successfully' });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const getFolders = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const category = canonicalCategory(typeof req.query.category === 'string' ? req.query.category : undefined);
        const memberId = typeof req.query.memberId === 'string' ? req.query.memberId.trim() : '';

        const folderQuery: any = { familyId };
        if (category === 'Shared') {
            folderQuery.$or = [
                { category: 'Shared' },
                { category: 'Individual' }, // legacy
            ];
        } else {
            folderQuery.category = category;
        }

        if (memberId) {
            if (category === 'Shared') {
                folderQuery.$and = [
                    { $or: folderQuery.$or ?? [{ category: category }] },
                    { $or: [{ memberId }, { memberId: { $exists: false } }] },
                ];
                delete folderQuery.$or;
            } else {
                folderQuery.memberId = memberId;
            }
        } else {
            folderQuery.memberId = { $exists: false };
        }

        const customFolders = await VaultFolder.find(folderQuery)
            .sort({ createdAt: 1 })
            .lean();
        
        // Get deleted built-in folders markers
        const deletedBuiltInQuery: any = {
            familyId,
            deleted: true,
        };
        if (category === 'Shared') {
            deletedBuiltInQuery.$or = [
                { category: 'Shared' },
                { category: 'Individual' },
            ];
        } else {
            deletedBuiltInQuery.category = category;
        }
        if (memberId) {
            deletedBuiltInQuery.memberId = memberId;
        } else {
            deletedBuiltInQuery.memberId = { $exists: false };
        }
        const deletedBuiltIns = await VaultFolder.find(deletedBuiltInQuery).lean();
        const deletedBuiltInNames = new Set(deletedBuiltIns.map((f: any) => f.name));
        
        const documentQuery: any = { familyId };
        if (category === 'Shared') {
            documentQuery.$or = [
                { category: 'Shared' },
                { category: 'Individual' }, // legacy
            ];
        } else {
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
            } else {
                documentQuery.$or = memberScope;
            }
        }
        const documentFolders = await Document.distinct('folder', documentQuery);

        const merged = new Set<string>([
            ...(BUILT_IN_FOLDERS[category] || []).filter(name => !deletedBuiltInNames.has(name)),
            ...customFolders.map((f: any) => (f.name || '').trim()).filter((name) => {
                const folder = customFolders.find((cf: any) => cf.name === name);
                return name && !folder?.deleted;
            }),
            ...documentFolders.map((f: any) => (f || '').toString().trim()).filter(Boolean),
        ]);

        // Build folder details array
        const folderDetails = Array.from(merged).map(name => {
            const builtIn = (BUILT_IN_FOLDERS[category] || []).includes(name);
            const custom = customFolders.find((f: any) => f.name === name);
            return {
                name,
                isBuiltIn: builtIn,
                isCustom: !!custom,
                folderId: custom?._id?.toString(),
                isSystem: false, // Allow all folders to be deletable
            };
        });

        res.status(200).json({
            category,
            folders: Array.from(merged), // Keep for backward compatibility
            folderDetails, // New detailed format
        });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const createFolder = async (req: Request, res: Response) => {
    try {
        const { familyId, category, name, memberId } = req.body;
        const normalizedName = (name || '').trim();
        if (!familyId || !category || !normalizedName) {
            return res.status(400).json({ message: 'familyId, category and name are required' });
        }

        const categoryValue = canonicalCategory(category);
        const existing = await VaultFolder.findOne({
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

        const folder = await VaultFolder.create({
            familyId,
            category: categoryValue,
            memberId: memberId || undefined,
            name: normalizedName,
            isSystem: false,
        });

        res.status(201).json(folder);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const moveDocumentToFolder = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { folder, memberId } = req.body;
        const normalizedFolder = (folder || '').trim();
        if (!normalizedFolder) {
            return res.status(400).json({ message: 'folder is required' });
        }

        const updated = await Document.findByIdAndUpdate(
            id,
            { folder: normalizedFolder, ...(memberId ? { memberId } : {}) },
            { new: true }
        );
        if (!updated) {
            return res.status(404).json({ message: 'Document not found' });
        }

        res.status(200).json(updated);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const deleteFolder = async (req: Request, res: Response) => {
    try {
        const { folderId } = req.params;
        const { folderName, familyId, category, memberId } = req.body;
        
        // Try to find existing folder
        let folder = folderId ? await VaultFolder.findById(folderId) : null;
        
        // If no folder found and folderName provided, this might be a built-in folder
        if (!folder && folderName && familyId && category) {
            const categoryValue = canonicalCategory(category);
            const builtInFolders = BUILT_IN_FOLDERS[categoryValue] || [];
            
            if (builtInFolders.includes(folderName)) {
                // Create a deleted marker for built-in folder
                folder = await VaultFolder.create({
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
        const documentsInFolder = await Document.countDocuments({
            familyId: folder.familyId,
            category: folder.category,
            folder: folder.name,
            ...(folder.memberId ? { memberId: folder.memberId } : {}),
        });

        if (documentsInFolder > 0) {
            return res.status(400).json({ 
                message: 'Cannot delete folder with documents. Please move or delete all documents first.',
                documentCount: documentsInFolder 
            });
        }

        // Mark as deleted instead of actually deleting (for potential recovery)
        await VaultFolder.findByIdAndUpdate(folder._id, { deleted: true });

        res.status(200).json({ message: 'Folder deleted successfully' });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const getTrashedDocuments = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;

        const documents = await Document.find({ 
            familyId, 
            deleted: true 
        })
            .sort({ deletedAt: -1 })
            .populate('uploadedBy', 'name');

        res.status(200).json({ documents });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const restoreDocument = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const document = await Document.findById(id);

        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }

        if (!document.deleted) {
            return res.status(400).json({ message: 'Document is not in trash' });
        }

        // Restore document
        document.deleted = false;
        document.deletedAt = undefined;
        await document.save();

        res.status(200).json({ message: 'Document restored successfully', document });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const permanentlyDeleteDocument = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const document = await Document.findById(id);

        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }

        // Delete from Cloudinary
        await cloudinary.uploader.destroy(document.cloudinaryId as string);

        // Permanently delete from MongoDB
        await Document.findByIdAndDelete(id);

        res.status(200).json({ message: 'Document permanently deleted' });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};
