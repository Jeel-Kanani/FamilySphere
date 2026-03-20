import { GoogleGenerativeAI } from '@google/generative-ai';
import IntelligenceFact, { FactSourceType, FactType, FactStatus } from '../../models/IntelligenceFact';
import mongoose from 'mongoose';
import { SmartIntelligence } from '../ocrService';
import { DocumentEngine } from './engines/DocumentEngine';
import { ExpenseEngine } from './engines/ExpenseEngine';
import { CalendarEngine } from './engines/CalendarEngine';
import { RecommendationEngine } from './engines/RecommendationEngine';

export interface IntelligencePayload {
    familyId: string;
    userId: string;
    sourceType: FactSourceType;
    sourceId: string;
    rawText: string;
    intelligence?: SmartIntelligence;
    aiModel?: string;
    confidence?: number;
}

export class IntelligenceCoreService {
    private static geminiClient: GoogleGenerativeAI | null = null;

    private static getClient(): GoogleGenerativeAI | null {
        if (this.geminiClient) return this.geminiClient;
        const key = process.env.GEMINI_API_KEY;
        if (!key || key === 'your_gemini_api_key_here') return null;
        this.geminiClient = new GoogleGenerativeAI(key);
        return this.geminiClient;
    }

    /**
     * processSource
     * The universal entry point for turning raw data into structured family facts.
     */
    static async processSource(payload: IntelligencePayload): Promise<void> {
        console.log(`[Intel-Core] Processing ${payload.sourceType} fact for source: ${payload.sourceId}`);
        
        try {
            // 1. Determine Fact Type base on classification or text
            const factType = payload.intelligence 
                ? this.mapCategoryToFactType(payload.intelligence.document_classification.category || '')
                : this.determineFactType(payload.rawText);

            // 2. Prepare Data Object (Normalization happens here)
            const data: Record<string, any> = {};
            let enrichedTags: string[] = payload.intelligence?.tags || [];

            if (payload.intelligence) {
                const intel = payload.intelligence;
                
                // --- Phase 3: Delegate to Domain Engines ---
                if (payload.sourceType === FactSourceType.DOCUMENT) {
                    const engineResult = await DocumentEngine.processIntelligence(intel);
                    data.domain_insights = {
                        action_suggestions: engineResult.actionSuggestions,
                        refined_summary: engineResult.summary
                    };
                    enrichedTags = engineResult.tags;

                    // Also run Expense Engine if it's financial
                    if (intel.document_flags.is_financial_document) {
                        const expenseResult = await ExpenseEngine.processIntelligence(intel);
                        data.domain_insights.expense_insights = expenseResult.insights;
                        data.domain_insights.is_recurring_expense = expenseResult.isRecurring;
                    }

                    // Also run Calendar Engine for events
                    const calendarResult = await CalendarEngine.processIntelligence(intel);
                    data.domain_insights.calendar_events = calendarResult.events;
                    data.domain_insights.is_time_sensitive = calendarResult.isTimeSensitive;
                }

                data.classification = intel.document_classification;
                data.entities = intel.entities;
                data.summary = data.domain_insights?.refined_summary || intel.brief_summary;
                data.importance = intel.importance;
                data.risk = intel.risk_analysis;
                data.suggested_events = intel.suggested_events;
            }

            // 3. Store the Fact
            const fact = await IntelligenceFact.findOneAndUpdate(
                { sourceId: payload.sourceId, sourceType: payload.sourceType },
                {
                    $set: {
                        familyId: new mongoose.Types.ObjectId(payload.familyId),
                        userId: new mongoose.Types.ObjectId(payload.userId),
                        sourceType: payload.sourceType,
                        sourceId: new mongoose.Types.ObjectId(payload.sourceId),
                        factType,
                        data,
                        confidence: payload.intelligence?.overall_confidence || payload.confidence || 0.0,
                        aiModel: payload.intelligence?.ai_model || payload.aiModel || 'manual',
                        tags: enrichedTags,
                        status: FactStatus.PENDING_REVIEW,
                    }
                },
                { upsert: true, new: true, setDefaultsOnInsert: true }
            );

            console.log(`[Intel-Core] ✓ Saved Enriched Fact (${factType}) for ${payload.sourceType} ${payload.sourceId}`);
            
            // 4. Trigger Automations (Phase 4)
            // await AutomationService.triggerForFact(fact);
            
        } catch (error) {
            console.error(`[Intel-Core] ❌ Failed to process source ${payload.sourceId}:`, error);
            throw error;
        }
    }

    private static mapCategoryToFactType(category: string): FactType {
        const cat = category.toLowerCase();
        if (cat.includes('finance') || cat.includes('tax') || cat.includes('bill') || cat.includes('finance')) return FactType.FINANCIAL;
        if (cat.includes('identity') || cat.includes('personal')) return FactType.IDENTITY;
        if (cat.includes('legal')) return FactType.LEGAL;
        if (cat.includes('medical') || cat.includes('health')) return FactType.MEDICAL;
        if (cat.includes('educational') || cat.includes('study')) return FactType.EDUCATIONAL;
        return FactType.GENERIC;
    }

    private static determineFactType(text: string): FactType {
        const lower = text.toLowerCase();
        if (lower.includes('bill') || lower.includes('invoice') || lower.includes('receipt') || lower.includes('amount')) {
            return FactType.FINANCIAL;
        }
        if (lower.includes('license') || lower.includes('passport') || lower.includes('aadhaar') || lower.includes('id')) {
            return FactType.IDENTITY;
        }
        if (lower.includes('court') || lower.includes('agreement') || lower.includes('contract')) {
            return FactType.LEGAL;
        }
        if (lower.includes('medical') || lower.includes('lab') || lower.includes('doctor') || lower.includes('prescription')) {
            return FactType.MEDICAL;
        }
        return FactType.GENERIC;
    }

    /**
     * Shared Date Normalizer
     */
    static normalizeDate(dateStr: string | null): Date | null {
        if (!dateStr) return null;
        const parsed = new Date(dateStr);
        return isNaN(parsed.getTime()) ? null : parsed;
    }
}
