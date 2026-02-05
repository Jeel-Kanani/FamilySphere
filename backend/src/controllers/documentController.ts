import { Request, Response } from 'express';
import Document from '../models/Document';
import { cloudinary } from '../config/cloudinary';

export const uploadDocument = async (req: Request, res: Response) => {
    try {
        const { title, category, familyId, uploadedBy } = req.body;
        const file = req.file as any;

        console.log('--- Upload Document ---');
        console.log('Body:', req.body);
        console.log('File:', file ? { mimetype: file.mimetype, size: file.size } : 'NONE');

        if (!file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const newDocument = new Document({
            title,
            category,
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
        const { category } = req.query;

        console.log('--- Get Documents ---');
        console.log('Family ID:', familyId);
        console.log('Category Filter:', category);

        const query: any = { familyId };
        if (category) {
            query.category = category;
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
