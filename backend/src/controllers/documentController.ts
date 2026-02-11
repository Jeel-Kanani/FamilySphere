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

        const newDocument = new Document({
            title,
            category: canonicalCategory(category),
            folder: (folder || 'General').trim() || 'General',
            memberId: memberId || undefined,
            fileUrl: file.path,
            fileType: file.mimetype,
            fileSize: file.size,
            cloudinaryId: file.filename,
            familyId,
            uploadedBy,
        });

        await newDocument.save();
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

        const query: any = { familyId };
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

        // Calculate total storage usage for this family
        const allDocs = await Document.find({ familyId });
        const totalSize = allDocs.reduce((acc, doc) => acc + (doc.fileSize || 0), 0);

        res.status(200).json({
            documents,
            storageUsed: totalSize,
            storageLimit: 25 * 1024 * 1024 * 1024, // 25 GB limit
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

        // Delete from Cloudinary
        await cloudinary.uploader.destroy(document.cloudinaryId as string);

        // Delete from MongoDB
        await Document.findByIdAndDelete(id);

        res.status(200).json({ message: 'Document deleted successfully' });
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
            ...(BUILT_IN_FOLDERS[category] || []),
            ...customFolders.map((f: any) => (f.name || '').trim()).filter(Boolean),
            ...documentFolders.map((f: any) => (f || '').toString().trim()).filter(Boolean),
        ]);

        res.status(200).json({
            category,
            folders: Array.from(merged),
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
