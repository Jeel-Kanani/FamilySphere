import IntelligenceFact, { FactType } from "../../../models/IntelligenceFact";

export interface Recommendation {
    id: string;
    title: string;
    description: string;
    priority: 'low' | 'medium' | 'high' | 'critical';
    category: string;
    actionLink?: string;
}

export class RecommendationEngine {
    /**
     * generateDailyBriefing
     * Aggregates recent facts and generates a prioritized recommendation list for a family.
     */
    static async generateDailyBriefing(familyId: string): Promise<Recommendation[]> {
        // Fetch pending facts for this family
        const facts = await IntelligenceFact.find({ 
            familyId, 
            status: 'pending_review' 
        }).sort({ confidence: -1 }).limit(10);

        const recommendations: Recommendation[] = [];

        for (const fact of facts) {
            let priority: Recommendation['priority'] = 'low';
            let title = '';
            let description = '';

            // Logic based on fact type and domain insights
            const insights = fact.data?.domain_insights;

            switch (fact.factType) {
                case FactType.FINANCIAL:
                    priority = (fact.confidence > 0.8) ? 'high' : 'medium';
                    title = 'Review Expense';
                    description = insights?.refined_summary || 'A new financial document requires your attention.';
                    if (insights?.is_recurring_expense) priority = 'medium';
                    break;
                
                case FactType.IDENTITY:
                    priority = 'critical';
                    title = 'Identity Document Detected';
                    description = `Verify details for ${insights?.refined_summary || 'your ID document'}.`;
                    break;

                case FactType.MEDICAL:
                    priority = 'high';
                    title = 'New Health Record';
                    description = insights?.refined_summary || 'Recent medical report analyzed.';
                    break;

                default:
                    priority = 'low';
                    title = 'New Insight';
                    description = fact.data?.summary || 'Information processed.';
            }

            recommendations.push({
                id: String(fact._id),
                title,
                description,
                priority,
                category: fact.factType,
                actionLink: `/intelligence/fact/${fact._id}`
            });
        }

        // Return sorted by priority
        const priorityScore = { critical: 4, high: 3, medium: 2, low: 1 };
        return recommendations.sort((a, b) => priorityScore[b.priority] - priorityScore[a.priority]);
    }
}
