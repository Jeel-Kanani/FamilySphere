import { SmartIntelligence } from "../../ocrService";

export interface DocumentActionSuggestion {
    label: string;
    actionType: 'task' | 'milestone' | 'info';
    reason: string;
    suggestedAt?: Date;
}

export class DocumentEngine {
    /**
     * processIntelligence
     * Refines the raw AI intelligence into domain-specific insights and action suggestions.
     */
    static async processIntelligence(intel: SmartIntelligence): Promise<{
        summary: string;
        actionSuggestions: DocumentActionSuggestion[];
        tags: string[];
    }> {
        const suggestions: DocumentActionSuggestion[] = [];
        const type = intel.document_classification.document_type?.toLowerCase() || '';
        const category = intel.document_classification.category?.toLowerCase() || '';

        // 1. Generate Domain-Specific Action Suggestions
        if (type.includes('passport')) {
            suggestions.push({
                label: 'Renew Passport',
                actionType: 'task',
                reason: 'Passports should typically be renewed 6-9 months before expiry to avoid travel issues.'
            });
            suggestions.push({
                label: 'Link with Visa',
                actionType: 'info',
                reason: 'Keep this passport scan together with any valid visas.'
            });
        } else if (type.includes('insurance') || category.includes('insurance')) {
            suggestions.push({
                label: 'Check Policy Coverage',
                actionType: 'task',
                reason: 'Review sum insured and coverage details for this policy.'
            });
            suggestions.push({
                label: 'Prepare Renewal',
                actionType: 'task',
                reason: 'Ensure premium is paid at least 7 days before due date.'
            });
        } else if (category.includes('medical') || type.includes('medical')) {
            suggestions.push({
                label: 'Share with Doctor',
                actionType: 'info',
                reason: 'Consider sharing this health record during your next consultation.'
            });
            suggestions.push({
                label: 'Track Health Trend',
                actionType: 'task',
                reason: 'This report adds a data point to your family health timeline.'
            });
        } else if (category.includes('bill') || category.includes('finance')) {
            suggestions.push({
                label: 'Confirm Payment',
                actionType: 'task',
                reason: 'Verify if this bill has been paid to avoid late fees.'
            });
        }

        // 2. High-level Summary Generation (Refining AI summary)
        let summary = intel.brief_summary || 'Analyzed document.';
        if (intel.document_classification.confidence > 0.8 && intel.entities.people.length > 0) {
            const firstPerson = intel.entities.people[0].name;
            if (firstPerson) {
                summary = `${intel.document_classification.document_type} for ${firstPerson}. ${summary}`;
            }
        }

        // 3. Smart Tags Enrichment
        const tags = [...(intel.tags || [])];
        if (intel.document_flags.is_identity_document) tags.push('identity_critical');
        if (intel.document_flags.is_financial_document) tags.push('financial_critical');

        return {
            summary,
            actionSuggestions: suggestions,
            tags: Array.from(new Set(tags))
        };
    }
}
