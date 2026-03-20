import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import path from 'path';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import connectDB from './config/db';
import mongoose from 'mongoose';
import authRoutes from './routes/authRoutes';
import familyRoutes from './routes/familyRoutes';
import documentRoutes from './routes/documentRoutes';
import vaultRoutes from './routes/vaultRoutes';
import eventRoutes from './routes/eventRoutes';
import adminRoutes from './routes/adminRoutes';
import intelligenceRoutes from './routes/intelligenceRoutes';

import { initScheduler } from './services/scheduler';
import { startOcrWorker } from './workers/ocrWorker';
import { ocrQueue } from './queues/ocrQueue';
import { isRedisAvailable, checkRedisWithRetries, redisConnectionOptions } from './config/redis';
import { appState } from './config/appState';

connectDB();
initScheduler();

// Phase 4 — Only start the BullMQ worker when Redis is reachable.
// Falls back to direct (synchronous) OCR processing in documentController.
// Emergency Demo Bypass: Forcibly disable Redis queue to prevent ECONNRESET errors
appState.ocrQueueEnabled = false;
console.log('[Server] 🚨 EMERGENCY: AI/Redis Queue forcibly disabled for demonstration.');
/*
checkRedisWithRetries().then((available) => {
    appState.ocrQueueEnabled = available;
    if (available) {
        startOcrWorker();
    } else {
        const host = (redisConnectionOptions as any).host || '127.0.0.1';
        const port = (redisConnectionOptions as any).port || 6379;
        console.warn(
            `[Server] Redis not available at ${host}:${port} — OCR queue disabled. ` +
            'Documents will be processed synchronously.\n' +
            '[Server] To enable the queue: start Redis, then restart the server.'
        );
    }
});
*/

const app = express();

app.use((req, res, next) => {
    console.log(`[GLOBAL LOG] ${req.method} ${req.url}`);
    next();
});

app.use(morgan('dev'));
app.use(cors());
app.use(helmet());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

app.get('/ping', (req, res) => {
    res.status(200).send('FamilySphere is awake!');
});

// Health endpoint for Render: reports Mongo, Redis reachability, and queue flag
app.get('/api/health', async (req, res) => {
    const mongoState = mongoose.connection.readyState === 1 ? 'up' : 'down';
    let redisState: 'up' | 'down' = 'down';
    try {
        const reachable = await isRedisAvailable();
        redisState = reachable ? 'up' : 'down';
    } catch (err) {
        redisState = 'down';
    }

    res.status(200).json({
        status: 'ok',
        mongo: mongoState,
        redis: redisState,
        ocrQueueEnabled: appState.ocrQueueEnabled,
        timestamp: new Date().toISOString(),
    });
});

// Real-time Queue Stats
app.get('/api/health/queues', async (req, res) => {
    try {
        const counts = await ocrQueue.getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed');
        res.status(200).json({
            queue: 'ocr',
            counts,
            timestamp: new Date().toISOString(),
        });
    } catch (err: any) {
        res.status(500).json({ error: 'Failed to fetch queue stats', details: err.message });
    }
});

app.use('/api/auth', authRoutes);
app.use('/api/families', familyRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/vault', vaultRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/intelligence', intelligenceRoutes);

const PORT = process.env.PORT || 5000;

app.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`Server running on all interfaces at port ${PORT}`);
});
