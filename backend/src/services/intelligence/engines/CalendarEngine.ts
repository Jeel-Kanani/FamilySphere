import { SmartIntelligence } from "../../ocrService";

export interface SmartEvent {
    title: string;
    start: Date;
    end?: Date;
    location?: string;
    description: string;
    confidence: number;
    type: 'appointment' | 'deadline' | 'reminder';
}

export class CalendarEngine {
    /**
     * processIntelligence
     * Extracts and validates calendar events from document intelligence.
     */
    static async processIntelligence(intel: SmartIntelligence): Promise<{
        events: SmartEvent[];
        isTimeSensitive: boolean;
    }> {
        const events: SmartEvent[] = [];
        const importantDates = intel.entities.important_dates;
        const type = intel.document_classification.document_type?.toLowerCase() || '';

        // 1. Map Suggested Events from OCR
        if (intel.suggested_events && intel.suggested_events.length > 0) {
            intel.suggested_events.forEach(e => {
                if (e.date) {
                    events.push({
                        title: e.title || 'Untitled Event',
                        start: new Date(e.date),
                        description: `Automatically detected event from ${type}.`,
                        confidence: intel.document_classification.confidence,
                        type: this.inferEventType(e.title || '', type)
                    });
                }
            });
        }

        // 2. Extra Date Parsing (Heuristics)
        const expiryDate = importantDates.find(d => d.label?.toLowerCase().includes('expir'))?.value;
        if (expiryDate && !events.some(e => e.title.toLowerCase().includes('expir'))) {
            events.push({
                title: `Expiry: ${intel.document_classification.subcategory || type}`,
                start: new Date(expiryDate),
                description: `Automatically detected expiry date from ${type}.`,
                confidence: 0.85,
                type: 'deadline'
            });
        }

        const dueDate = importantDates.find(d => d.label?.toLowerCase().includes('due'))?.value;
        if (dueDate && !events.some(e => e.title.toLowerCase().includes('due'))) {
            events.push({
                title: `Due: ${intel.document_classification.subcategory || type}`,
                start: new Date(dueDate),
                description: `Payment or action due date detected.`,
                confidence: 0.9,
                type: 'deadline'
            });
        }

        return {
            events,
            isTimeSensitive: events.length > 0
        };
    }

    private static inferEventType(title: string, docType: string): 'appointment' | 'deadline' | 'reminder' {
        const t = title.toLowerCase();
        const d = docType.toLowerCase();
        if (t.includes('visit') || t.includes('meet') || t.includes('appointment') || d.includes('ticket')) return 'appointment';
        if (t.includes('due') || t.includes('expiry') || t.includes('deadline') || t.includes('last date')) return 'deadline';
        return 'reminder';
    }
}
