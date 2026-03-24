import { Request, Response } from 'express';
import mongoose from 'mongoose';
import Document from '../models/Document';
import VaultFolder from '../models/VaultFolder';
import DocumentIntelligence, { ALLOWED_DOC_TYPES } from '../models/DocumentIntelligence';
import { cloudinary } from '../config/cloudinary';
import { ocrQueue } from '../queues/ocrQueue';
import { appState } from '../config/appState';
import Family from '../models/Family';

const escapeRegex = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const BUILT_IN_FOLDERS: Record<string, string[]> = {
    Shared: [
        'Property Deed',
        'Medical',
        'Insurance',
        'Vehicle',
        'Finance & Tax',
        'Legal',
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

const getAuthenticatedUser = (req: Request) => (req as any).user;

const getAuthenticatedUserId = (req: Request): string | null => {
    const user = getAuthenticatedUser(req);
    return user?._id ? String(user._id) : null;
};

const getAuthenticatedFamilyId = (req: Request): string | null => {
    const user = getAuthenticatedUser(req);
    return user?.familyId ? String(user.familyId) : null;
};

const isFamilyAdmin = (req: Request): boolean => getAuthenticatedUser(req)?.role === 'admin';

const ensureFamilyAccess = (req: Request, familyId: string): string | null => {
    const userId = getAuthenticatedUserId(req);
    const requesterFamilyId = getAuthenticatedFamilyId(req);

    if (!userId || !requesterFamilyId) {
        return null;
    }

    return requesterFamilyId === String(familyId) ? userId : null;
};

const canActForMember = (req: Request, memberId?: string): boolean => {
    if (!memberId) {
        return true;
    }

    const userId = getAuthenticatedUserId(req);
    if (!userId) {
        return false;
    }

    return isFamilyAdmin(req) || userId === String(memberId);
};

const getAuthorizedDocumentById = async (req: Request, documentId: string) => {
    const requesterFamilyId = getAuthenticatedFamilyId(req);
    if (!requesterFamilyId) {
        return null;
    }

    const document = await Document.findById(documentId);
    if (!document) {
        return null;
    }

    return String(document.familyId) === requesterFamilyId ? document : null;
};

/** Fire-and-forget OCR when Redis / BullMQ is unavailable. */
const runOcrDirectly = (docId: any, fileUrl: string, familyId: string) => {
    Promise.all([
        import('../services/ocrService'),
        import('../services/eventGeneratorService'),
        import('../services/intelligence/IntelligenceCore'),
        import('../models/IntelligenceFact'),
    ]).then(async ([{ processDocumentOcr }, { EventGeneratorService }, { IntelligenceCoreService }, { FactSourceType }]) => {
        try {
            const ocrResult = await processDocumentOcr(fileUrl);
            await Document.findByIdAndUpdate(docId, {
                rawText: ocrResult.rawText,
                docType: ocrResult.docType,
                expiryDate: ocrResult.expiryDate,
                dueDate: ocrResult.dueDate,
                amount: ocrResult.amount,
                ocrStatus: 'done',
                ocrConfidence: ocrResult.confidence,
            });
            const updatedDoc = await Document.findById(docId);
            if (updatedDoc) {
                // 🔥 Unified Intelligence Platform: Create a Fact
                try {
                    await IntelligenceCoreService.processSource({
                        familyId: String(updatedDoc.familyId),
                        userId: String(updatedDoc.uploadedBy),
                        sourceType: FactSourceType.DOCUMENT,
                        sourceId: String(updatedDoc._id),
                        rawText: ocrResult.rawText,
                        intelligence: ocrResult.intelligence,
                    });
                } catch (intelErr: any) {
                    console.error('[Upload] Direct Intel Fact failed:', intelErr.message);
                }
                
                await EventGeneratorService.generateEventsFromDocument(updatedDoc);
            }
        } catch (err: any) {
            console.error('[Upload] Direct OCR failed:', err.message);
            await Document.findByIdAndUpdate(docId, { ocrStatus: 'failed' });
        }
    });
};

export const uploadDocument = async (req: Request, res: Response) => {
    try {
        let body = req.body;
        if (req.body.metadata && typeof req.body.metadata === 'string') {
            try {
                body = { ...body, ...JSON.parse(req.body.metadata) };
            } catch (e) {
                console.warn('Failed to parse metadata JSON:', e);
            }
        }

        const { title, category, familyId, folder, memberId } = body;
        const file = req.file as any;
        const userId = ensureFamilyAccess(req, String(familyId));

        console.log('--- Upload Document ---');
        console.log('Body:', req.body);
        console.log('File:', file ? { mimetype: file.mimetype, size: file.size } : 'NONE');

        if (!userId) {
            return res.status(403).json({ message: 'Not allowed to upload to this family' });
        }

        if (!canActForMember(req, memberId)) {
            return res.status(403).json({ message: 'Not allowed to upload for this member' });
        }

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
            uploadedBy: userId,
            ocrStatus: 'pending',
        });

        await newDocument.save();

        // Update family storage
        await Family.findByIdAndUpdate(familyId, {
            $inc: { storageUsed: file.size || 0 }
        });
        // 🔥 Phase 4: Dispatch OCR + event generation to BullMQ background worker.
        // If Redis was not available at startup, skip the queue entirely and run
        // OCR directly in the background so the upload never fails.
        let ocrJobId: string | undefined;
        if (appState.ocrQueueEnabled) {
            try {
                const job = await ocrQueue.add(
                    'ocr-job',
                    {
                        documentId: String(newDocument._id),
                        fileUrl: file.path,
                        familyId: String(familyId),
                    },
                    { jobId: `doc-${newDocument._id}` }
                );
                ocrJobId = job.id;
                await Document.findByIdAndUpdate(newDocument._id, { ocrJobId });
            } catch (queueErr: any) {
                console.warn('[Upload] Queue error, running OCR directly:', queueErr.message);
                runOcrDirectly(newDocument._id, file.path, familyId);
            }
        } else {
            // Redis unavailable — run OCR directly in background (fire-and-forget)
            runOcrDirectly(newDocument._id, file.path, familyId);
        }

        res.status(201).json({ 
            ...newDocument.toObject(), 
            documentId: newDocument._id, // Standardized for tests/frontend
            processingStatus: newDocument.ocrStatus, // Alias for tests
            ocrJobId 
        });
    } catch (error: any) {
        console.error('[Upload] ERROR:', error);
        res.status(500).json({ 
            message: error.message || 'Server error uploading document',
            error: error.stack || error
        });
    }
};

export const getDocuments = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const { category, folder, memberId } = req.query;
        const userId = ensureFamilyAccess(req, String(familyId));

        console.log('--- Get Documents ---');
        console.log('Family ID:', familyId);
        console.log('Category Filter:', category);

        if (!userId) {
            return res.status(403).json({ message: 'Not allowed to access this family' });
        }

        const query: any = { familyId, deleted: false };
        const normalizedCategory = typeof category === 'string' ? category.trim() : '';
        const categoryValue = normalizedCategory ? canonicalCategory(normalizedCategory) : '';
        if (normalizedCategory) {
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
        let normalizedMemberId = typeof memberId === 'string' ? memberId.trim() : '';
        if ((categoryValue === 'Personal' || categoryValue === 'Private') && !isFamilyAdmin(req)) {
            normalizedMemberId = userId;
        }
        if (normalizedMemberId && !canActForMember(req, normalizedMemberId)) {
            return res.status(403).json({ message: 'Not allowed to query documents for this member' });
        }
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
        const family = await Family.findById(String(familyId));

        let storageUsed = family?.storageUsed || 0;
        const storageLimit = family?.storageLimit || (25 * 1024 * 1024 * 1024);

        // Periodically recalculate storage to fix any discrepancies (every 10th request)
        if (Math.random() < 0.1) {
            const allDocs = await Document.find({ familyId: String(familyId), deleted: false });
            const actualSize = allDocs.reduce((acc, doc) => acc + (doc.fileSize || 0), 0);
            if (Math.abs(actualSize - storageUsed) > 1024) { // Update if difference > 1KB
                storageUsed = actualSize;
                await Family.findByIdAndUpdate(String(familyId), { storageUsed: actualSize });
            }
        }

        res.status(200).json({
            documents: documents.map(doc => ({
                ...doc.toObject(),
                documentId: doc._id // Standardized for tests/frontend
            })),
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
        const document = await getAuthorizedDocumentById(req, String(id));

        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }

        // Ownership check: Only admin or the person who uploaded can delete
        const userId = getAuthenticatedUser(req)?._id;
        if (!isFamilyAdmin(req) && document.uploadedBy?.toString() !== String(userId)) {
            return res.status(403).json({ message: 'Not authorized: You can only delete your own documents' });
        }

        // Update family storage
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
        const userId = ensureFamilyAccess(req, String(familyId));
        let memberId = typeof req.query.memberId === 'string' ? req.query.memberId.trim() : '';

        if (!userId) {
            return res.status(403).json({ message: 'Not allowed to access this family' });
        }

        if ((category === 'Personal' || category === 'Private') && !isFamilyAdmin(req)) {
            memberId = userId;
        }

        if (memberId && !canActForMember(req, memberId)) {
            return res.status(403).json({ message: 'Not allowed to access folders for this member' });
        }

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

        if (!ensureFamilyAccess(req, String(familyId))) {
            return res.status(403).json({ message: 'Not allowed to create folders in this family' });
        }

        if (!canActForMember(req, memberId)) {
            return res.status(403).json({ message: 'Not allowed to create folders for this member' });
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
        const document = await getAuthorizedDocumentById(req, String(id));
        if (!normalizedFolder) {
            return res.status(400).json({ message: 'folder is required' });
        }

        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }

        if (!canActForMember(req, memberId)) {
            return res.status(403).json({ message: 'Not allowed to move document for this member' });
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

        if (familyId && !ensureFamilyAccess(req, String(familyId))) {
            return res.status(403).json({ message: 'Not allowed to delete folders in this family' });
        }

        if (!canActForMember(req, memberId)) {
            return res.status(403).json({ message: 'Not allowed to delete folders for this member' });
        }

        // Try to find existing folder (validate ObjectId first to avoid cast errors)
        const isValidId = folderId && mongoose.Types.ObjectId.isValid(folderId as string);
        let folder = isValidId ? await VaultFolder.findById(folderId) : null;

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

        const requesterFamilyId = getAuthenticatedFamilyId(req);
        if (!requesterFamilyId || requesterFamilyId !== String(folder.familyId)) {
            return res.status(403).json({ message: 'Not allowed to delete this folder' });
        }

        if (!canActForMember(req, folder.memberId ? String(folder.memberId) : undefined)) {
            return res.status(403).json({ message: 'Not allowed to delete this folder' });
        }

        // Check if folder or any of its subfolders contains any documents
        const folderPrefix = `${folder.name}/`;
        const documentsInSubtree = await Document.countDocuments({
            familyId: folder.familyId,
            category: folder.category,
            $or: [
                { folder: folder.name },
                { folder: { $regex: `^${escapeRegex(folderPrefix)}` } }
            ],
            ...(folder.memberId ? { memberId: folder.memberId } : {}),
            deleted: false
        });

        if (documentsInSubtree > 0) {
            return res.status(400).json({
                message: 'Cannot delete folder containing documents. Please move or delete all documents in this folder and its subfolders first.',
                documentCount: documentsInSubtree
            });
        }

        // Mark this folder and all subfolders as deleted
        await VaultFolder.updateMany(
            {
                familyId: folder.familyId,
                category: folder.category,
                $or: [
                    { _id: folder._id },
                    { name: { $regex: `^${escapeRegex(folderPrefix)}` } }
                ],
                ...(folder.memberId ? { memberId: folder.memberId } : {})
            },
            { deleted: true }
        );

        res.status(200).json({ message: 'Folder and subfolders deleted successfully' });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};



export const getTrashedDocuments = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        if (!ensureFamilyAccess(req, String(familyId))) {
            return res.status(403).json({ message: 'Not allowed to access this family' });
        }

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
        const document = await getAuthorizedDocumentById(req, String(id));

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
        const document = await getAuthorizedDocumentById(req, String(id));

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

// ── Phase 4: OCR Job Status ───────────────────────────────────────────────────

/**
 * POST /api/documents/requeue-stuck
 * Re-queues all documents stuck in 'pending' or 'processing' ocrStatus.
 * Useful after Redis was temporarily unavailable and documents never got processed.
 */
export const requeueStuckDocuments = async (req: Request, res: Response) => {
    try {
        if (!appState.ocrQueueEnabled) {
            return res.status(503).json({ message: 'OCR queue is not enabled — Redis not connected.' });
        }

        const familyId = getAuthenticatedFamilyId(req);
        if (!familyId || !isFamilyAdmin(req)) {
            return res.status(403).json({ message: 'Only family admins can requeue OCR jobs' });
        }

        const stuckDocs = await Document.find({
            familyId,
            ocrStatus: { $in: ['pending', 'processing'] },
            deletedAt: null,
        }).select('_id fileUrl familyId title');

        if (stuckDocs.length === 0) {
            return res.status(200).json({ message: 'No stuck documents found.', requeued: 0 });
        }

        let requeued = 0;
        const errors: string[] = [];

        for (const doc of stuckDocs) {
            try {
                // Reset to pending so the worker sets it to 'processing' when it starts
                await Document.findByIdAndUpdate(doc._id, { ocrStatus: 'pending' });
                await ocrQueue.add(
                    'ocr-job',
                    {
                        documentId: String(doc._id),
                        fileUrl: doc.fileUrl,
                        familyId: String(doc.familyId),
                    },
                    {
                        jobId: `requeue-${doc._id}-${Date.now()}`,
                        removeOnComplete: { count: 200 },
                        removeOnFail: { count: 100 },
                    }
                );
                requeued++;
                console.log(`[Requeue] Queued doc ${doc._id} ("${doc.title}")`);
            } catch (err: any) {
                errors.push(`${doc._id}: ${err.message}`);
                console.error(`[Requeue] Failed to queue doc ${doc._id}: ${err.message}`);
            }
        }

        res.status(200).json({
            message: `Re-queued ${requeued} of ${stuckDocs.length} stuck documents.`,
            requeued,
            total: stuckDocs.length,
            errors: errors.length > 0 ? errors : undefined,
        });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

/**
 * GET /api/documents/:id/ocr-status
 * Lightweight polling endpoint so the mobile app can show real-time OCR progress.
 * Returns the document's current ocrStatus + extracted metadata once done.
 */
export const getOcrStatus = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const authorizedDocument = await getAuthorizedDocumentById(req, String(id));

        if (!authorizedDocument) {
            return res.status(404).json({ message: 'Document not found' });
        }

        const document = await Document.findById(id).select(
            'ocrStatus ocrConfidence docType expiryDate dueDate amount ocrJobId'
        );

        if (!document) {
            return res.status(404).json({ message: 'Document not found' });
        }

        res.status(200).json({
            ocrStatus: document.ocrStatus,
            ocrJobId: document.ocrJobId,
            ocrConfidence: document.ocrConfidence,
            docType: document.docType,
            expiryDate: document.expiryDate,
            dueDate: document.dueDate,
            amount: document.amount,
        });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// ── GET /api/documents/:id/intelligence ──────────────────────────────────────

/**
 * Returns the full DocumentIntelligence record for a document.
 * Used by the mobile app to display smart tags, entities, importance, etc.
 */
export const getDocumentIntelligence = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const authorizedDocument = await getAuthorizedDocumentById(req, String(id));

        if (!authorizedDocument) {
            return res.status(404).json({ message: 'No intelligence data found for this document.' });
        }

        const intelligence = await DocumentIntelligence.findOne({ documentId: id });

        if (!intelligence) {
            return res.status(404).json({ message: 'No intelligence data found for this document.' });
        }

        res.status(200).json(intelligence);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// ── PATCH /api/documents/:id/confirm-type ────────────────────────────────────

/**
 * User confirms or corrects the AI-detected document type.
 * Just updates the classification — does NOT re-run OCR/AI.
 */
export const confirmDocumentType = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { doc_type } = req.body;
        const authorizedDocument = await getAuthorizedDocumentById(req, String(id));

        if (!doc_type) {
            return res.status(400).json({ message: 'doc_type is required.' });
        }

        if (!authorizedDocument) {
            return res.status(404).json({ message: 'Document not found' });
        }

        // Validate against allowed types
        if (!ALLOWED_DOC_TYPES.includes(doc_type)) {
            return res.status(400).json({
                message: `Invalid doc_type. Allowed values: ${ALLOWED_DOC_TYPES.join(', ')}`,
            });
        }

        // Update DocumentIntelligence
        const intelligence = await DocumentIntelligence.findOneAndUpdate(
            { documentId: id },
            {
                $set: {
                    'classification.doc_type': doc_type,
                    needs_confirmation: false,
                },
            },
            { new: true }
        );

        // Also sync docType on the Document itself
        await Document.findByIdAndUpdate(id, {
            docType: doc_type,
            ocrStatus: 'done',
        });

        res.status(200).json({
            message: 'Document type confirmed.',
            doc_type,
            intelligence,
        });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

/**
 * PATCH /api/documents/:id/confirm-intelligence
 *
 * Called by the mobile UI after a Tier 2 (assist) document is reviewed.
 *
 * Body:
 * {
 *   doc_type?:         string           — user-confirmed or corrected doc type
 *   confirmed_events:  Array<{          — one entry per suggested_event index
 *     index: number,
 *     accepted: boolean,
 *     edited_title?: string,
 *     edited_date?:  string (YYYY-MM-DD)
 *   }>
 *   manual_entities?: {                 — optional user-supplied fields for Tier 3
 *     expiry_date?: string,
 *     due_date?:    string,
 *     amount?:      number
 *   }
 * }
 *
 * Behaviour:
 *  - Updates DocumentIntelligence with user decisions
 *  - For each accepted event, creates a real Event record via EventGeneratorService
 *  - Sets ocrStatus = 'done' on the Document
 */
export const confirmIntelligence = async (req: Request, res: Response) => {
    const { EventGeneratorService } = await import('../services/eventGeneratorService');
    const Event = (await import('../models/Event')).default;

    try {
        const { id } = req.params;
        const { doc_type, confirmed_events = [], manual_entities } = req.body;
        const authorizedDocument = await getAuthorizedDocumentById(req, String(id));

        if (!authorizedDocument) {
            return res.status(404).json({ message: 'Document not found' });
        }

        // ── Validate doc type if provided ────────────────────────────────────
        if (doc_type && !ALLOWED_DOC_TYPES.includes(doc_type)) {
            return res.status(400).json({
                message: `Invalid doc_type. Must be one of the allowed types.`,
            });
        }

        const intelligence = await DocumentIntelligence.findOne({ documentId: id });
        if (!intelligence) {
            return res.status(404).json({ message: 'No intelligence record found for this document.' });
        }

        // ── Apply user decisions to suggested_events ─────────────────────────
        const acceptedEventIndices: number[] = [];
        for (const decision of confirmed_events) {
            const { index, accepted, edited_title, edited_date } = decision;
            if (intelligence.suggested_events[index] === undefined) continue;

            intelligence.suggested_events[index].accepted = accepted;

            if (edited_title) {
                intelligence.suggested_events[index].title = edited_title;
            }
            if (edited_date) {
                const parsed = new Date(edited_date);
                if (!isNaN(parsed.getTime())) {
                    intelligence.suggested_events[index].date = parsed;
                }
            }

            if (accepted) acceptedEventIndices.push(index);
        }

        // ── Apply manual entity overrides (Tier 3 use case) ──────────────────
        if (manual_entities) {
            if (manual_entities.expiry_date) {
                const d = new Date(manual_entities.expiry_date);
                if (!isNaN(d.getTime())) intelligence.entities.expiry_date = d;
            }
            if (manual_entities.due_date) {
                const d = new Date(manual_entities.due_date);
                if (!isNaN(d.getTime())) intelligence.entities.due_date = d;
            }
            if (typeof manual_entities.amount === 'number') {
                intelligence.entities.amount = manual_entities.amount;
            }
        }

        // ── Update classification if user corrected doc type ─────────────────
        if (doc_type) {
            intelligence.classification.document_type = doc_type;
        }

        intelligence.needs_confirmation = false;
        intelligence.confirmation_tier = 'auto'; // resolved
        await intelligence.save();

        // ── Create Event records for user-accepted events only ───────────────
        if (acceptedEventIndices.length > 0) {
            const doc = await Document.findById(id);
            if (doc) {
                // Temporarily replace suggested_events with only accepted ones
                // so EventGeneratorService createSmartEvents only processes them
                const originalEvents = intelligence.suggested_events;
                const filteredEvents = acceptedEventIndices.map(i => originalEvents[i]);

                // Directly create events for accepted entries
                for (const ev of filteredEvents) {
                    const eventDate = ev.date instanceof Date ? ev.date : new Date(ev.date);
                    if (isNaN(eventDate.getTime())) continue;

                    const now = new Date();
                    const EventModel = Event;
                    await EventModel.create({
                        familyId: doc.familyId,
                        userId: doc.uploadedBy,
                        title: ev.title,
                        startDate: eventDate,
                        type: ev.event_type === 'expiry' ? 'expiry'
                            : ev.event_type === 'payment' ? 'bill_due'
                                : ev.event_type === 'milestone' ? 'milestone'
                                    : 'milestone',
                        status: eventDate < now ? 'expired' : 'upcoming',
                        source: 'ai',
                        relatedDocumentId: doc._id,
                        description: ev.reason || '',
                        priority: 3,
                        isUserModified: false,
                    });
                }

                console.log(
                    `[ConfirmIntel] Created ${filteredEvents.length} events for doc ${id} ` +
                    `| rejected=${confirmed_events.length - acceptedEventIndices.length}`
                );
            }
        }

        // ── Mark document as done ────────────────────────────────────────────
        const updatedDoc = await Document.findByIdAndUpdate(
            id,
            {
                ocrStatus: 'done',
                ...(doc_type ? { docType: doc_type } : {}),
                ...(manual_entities?.expiry_date ? { expiryDate: new Date(manual_entities.expiry_date) } : {}),
                ...(manual_entities?.due_date ? { dueDate: new Date(manual_entities.due_date) } : {}),
                ...(manual_entities?.amount ? { amount: manual_entities.amount } : {}),
            },
            { new: true }
        );

        return res.status(200).json({
            message: 'Intelligence confirmed.',
            events_created: acceptedEventIndices.length,
            events_rejected: confirmed_events.length - acceptedEventIndices.length,
            doc_type: updatedDoc?.docType,
            ocrStatus: updatedDoc?.ocrStatus,
        });
    } catch (error: any) {
        console.error('[ConfirmIntel] Error:', error.message);
        res.status(500).json({ message: error.message });
    }
};

/**
 * Manually re-trigger OCR processing for a specific document.
 * Useful if the initial job failed or if the user wants to re-scan.
 */
export const reprocessOcr = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const doc = await getAuthorizedDocumentById(req, String(id));

        if (!doc) {
            return res.status(404).json({ message: 'Document not found' });
        }

        if (!appState.ocrQueueEnabled) {
            return res.status(503).json({
                message: 'OCR queue is not enabled. Redis connection required for background processing.'
            });
        }

        // Reset status to pending
        doc.ocrStatus = 'pending';
        await doc.save();

        // Dispatch job to BullMQ
        await ocrQueue.add(
            'ocr',
            {
                documentId: doc._id.toString(),
                fileUrl: doc.fileUrl,
                familyId: doc.familyId.toString(),
            },
            { removeOnComplete: true, removeOnFail: false }
        );

        res.status(200).json({
            message: 'OCR reprocessing job queued successfully',
            documentId: doc._id,
            status: doc.ocrStatus
        });
    } catch (error: any) {
        console.error('[ReprocessOcr] Error:', error.message);
        res.status(500).json({ message: error.message });
    }
};
