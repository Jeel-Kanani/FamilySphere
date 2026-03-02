import dotenv from 'dotenv';
import path from 'path';

// Load env vars immediately before other imports
dotenv.config({ path: path.join(__dirname, '../../.env') });

import { ocrQueue } from '../queues/ocrQueue';

async function monitor() {
    console.log('--- FamilySphere Redis Queue Monitor ---');
    console.log('Press Ctrl+C to stop.\n');

    setInterval(async () => {
        try {
            const counts = await ocrQueue.getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed');
            const now = new Date().toLocaleTimeString();

            console.clear();
            console.log(`[${now}] OCR Queue Stats:`);
            console.log(`  Waiting:   ${counts.waiting}`);
            console.log(`  Active:    ${counts.active}`);
            console.log(`  Completed: ${counts.completed}`);
            console.log(`  Failed:    ${counts.failed}`);
            console.log(`  Delayed:   ${counts.delayed}`);

            if (counts.failed > 0) {
                const failedJobs = await ocrQueue.getFailed(0, 5);
                console.log('\nLatest Failed Jobs:');
                failedJobs.forEach(job => {
                    console.log(`  - Job ${job.id}: ${job.failedReason}`);
                });
            }
        } catch (err: any) {
            console.error(`Error fetching queue stats: ${err.message}`);
        }
    }, 2000);
}

monitor().catch(console.error);
