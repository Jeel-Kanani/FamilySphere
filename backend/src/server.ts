import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import { createServer } from 'http';
import { initSocket } from './services/socketService';
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
import hubRoutes from './routes/hubRoutes';
import chatRoutes from './routes/chatRoutes';

import { initScheduler } from './services/scheduler';
import { appState } from './config/appState';

connectDB();
initScheduler();

// Redis/Queue disabled - OCR processes synchronously (faster for small loads)
appState.ocrQueueEnabled = false;
console.log('[Server] ℹ️  OCR queue disabled - processing documents synchronously');

const app = express();
const httpServer = createServer(app);

// Initialize Socket.io with the HTTP server
initSocket(httpServer);

app.use((req, res, next) => {
    console.log(`[GLOBAL LOG] ${req.method} ${req.url}`);
    next();
});

app.use(morgan('dev'));

// CORS configuration - allow frontend origins
const allowedOrigins = [
    'http://localhost:3000',
    'http://localhost:5173',
    'https://familysphere.onrender.com',
    process.env.FRONTEND_URL,
].filter(Boolean);

app.use(cors({
    origin: (origin, callback) => {
        // Allow requests with no origin (mobile apps, Postman, etc.)
        if (!origin) return callback(null, true);
        if (allowedOrigins.includes(origin) || origin.includes('localhost')) {
            callback(null, true);
        } else {
            callback(null, true); // Allow all for now, can restrict later
        }
    },
    credentials: true,
}));

app.use(helmet());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

app.get('/ping', (req, res) => {
    res.status(200).send('FamilySphere is awake!');
});

// Health endpoint for Render: reports Mongo status
app.get('/api/health', async (req, res) => {
    const mongoState = mongoose.connection.readyState === 1 ? 'up' : 'down';

    res.status(200).json({
        status: 'ok',
        mongo: mongoState,
        ocrMode: 'synchronous',
        timestamp: new Date().toISOString(),
    });
});

// Queue stats disabled (synchronous OCR mode)
app.get('/api/health/queues', async (req, res) => {
    res.status(200).json({
        queue: 'disabled',
        mode: 'synchronous',
        message: 'OCR processes documents synchronously - no queue',
        timestamp: new Date().toISOString(),
    });
});

app.use('/api/auth', authRoutes);
app.use('/api/families', familyRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/vault', vaultRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/intelligence', intelligenceRoutes);
app.use('/api/hub', hubRoutes);
app.use('/api/chat', chatRoutes);

const PORT = process.env.PORT || 5000;

httpServer.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`Server running on all interfaces at port ${PORT} (Real-time Hub active)`);
});
