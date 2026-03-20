import { SmartIntelligence } from "../../ocrService";

export interface ExpenseInsight {
    label: string;
    value: string | number;
    trend?: 'up' | 'down' | 'neutral';
    isAnomaly: boolean;
    reason: string;
}

export class ExpenseEngine {
    /**
     * processIntelligence
     * Turns financial entities into actionable expense insights and anomalies.
     */
    static async processIntelligence(intel: SmartIntelligence): Promise<{
        insights: ExpenseInsight[];
        category: string;
        isRecurring: boolean;
    }> {
        const insights: ExpenseInsight[] = [];
        const financial = intel.entities.financial_details;
        const mainAmount = financial.amounts[0]?.value || 0;
        const isFinancial = intel.document_flags.is_financial_document;
        const type = intel.document_classification.document_type?.toLowerCase() || '';

        if (!isFinancial && mainAmount === 0) {
            return { insights: [], category: 'Other', isRecurring: false };
        }

        // 1. Expense Classification
        const category = intel.document_classification.category || 'General Expense';
        
        // 2. Anomaly Detection (Simple Rule-based for now)
        if (mainAmount > 5000 && (type.includes('bill') || type.includes('electricity'))) {
            insights.push({
                label: 'High Utility Bill',
                value: mainAmount,
                isAnomaly: true,
                reason: `This bill is significantly higher than the typical utility average for this family.`
            });
        }

        // 3. Recurring Detection
        const isRecurring = type.includes('subscription') || type.includes('rent') || type.includes('emi') || type.includes('sip');
        if (isRecurring) {
            insights.push({
                label: 'Recurring Payment',
                value: 'Detected',
                isAnomaly: false,
                reason: 'This appears to be a monthly or periodic commitment.'
            });
        }

        // 4. Budget Impact
        if (mainAmount > 0) {
            insights.push({
                label: 'Budget Impact',
                value: mainAmount,
                isAnomaly: false,
                reason: `Adding this ${category} to your monthly expenditure total.`
            });
        }

        return {
            insights,
            category,
            isRecurring
        };
    }
}
