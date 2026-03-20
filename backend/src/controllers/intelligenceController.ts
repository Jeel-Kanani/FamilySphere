import { Request, Response } from 'express';
import { RecommendationEngine } from '../services/intelligence/engines/RecommendationEngine';
import IntelligenceFact from '../models/IntelligenceFact';

export const getDailyBriefing = async (req: Request, res: Response) => {
    try {
        const familyId = String(req.params.familyId);
        const briefing = await RecommendationEngine.generateDailyBriefing(familyId);
        res.json(briefing);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const getRecentFacts = async (req: Request, res: Response) => {
    try {
        const { familyId } = req.params;
        const facts = await IntelligenceFact.find({ familyId })
            .sort({ createdAt: -1 })
            .limit(20);
        res.json(facts);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

export const getFactDetails = async (req: Request, res: Response) => {
    try {
        const { factId } = req.params;
        const fact = await IntelligenceFact.findById(factId);
        if (!fact) return res.status(404).json({ message: 'Fact not found' });
        res.json(fact);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};
