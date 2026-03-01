/**
 * Shared runtime state.
 * Set once at startup (server.ts) — read by controllers to skip the
 * OCR queue entirely when Redis was not available at boot time.
 */
export const appState = {
    ocrQueueEnabled: false,
};
