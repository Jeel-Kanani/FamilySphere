import { ConnectionOptions } from 'bullmq';
import * as net from 'net';

/**
 * BullMQ 5 bundles its own ioredis internally.
 * Supports either REDIS_URL (full URL — what Render provides) or
 * individual REDIS_HOST / REDIS_PORT / REDIS_PASSWORD env vars.
 */
const buildConnectionOptions = (): ConnectionOptions => {
    const url = process.env.REDIS_URL;
    if (url) {
        console.log('[Redis Config] Using REDIS_URL from environment');
        const parsed = new URL(url);
        return {
            host: parsed.hostname,
            port: parseInt(parsed.port || '6379', 10),
            password: parsed.password || undefined,
            username: parsed.username || undefined,
            maxRetriesPerRequest: null,
            enableReadyCheck: false,
            retryStrategy: () => null,
        };
    }
    const host = process.env.REDIS_HOST || '127.0.0.1';
    const port = parseInt(process.env.REDIS_PORT || '6379', 10);
    console.log(`[Redis Config] Using Host/Port: ${host}:${port}`);
    return {
        host: host,
        port: port,
        password: process.env.REDIS_PASSWORD || undefined,
        maxRetriesPerRequest: null,
        enableReadyCheck: false,
        retryStrategy: () => null,
    };
};

export const redisConnectionOptions: ConnectionOptions = buildConnectionOptions();

/**
 * Returns true if Redis is reachable at the configured host/port.
 * Used by server.ts to decide whether to start the BullMQ worker.
 */
export const isRedisAvailable = (): Promise<boolean> => {
    return new Promise((resolve) => {
        const host = (redisConnectionOptions as any).host || '127.0.0.1';
        const port = (redisConnectionOptions as any).port || 6379;
        const socket = net.createConnection({ host, port });
        const timeoutMs = 5000; // Increased to 5s for cloud/Render cold starts
        const timer = setTimeout(() => {
            console.warn(`[Redis Availability] Timeout after ${timeoutMs}ms connecting to ${host}:${port}`);
            socket.destroy();
            resolve(false);
        }, timeoutMs);
        socket.on('connect', () => {
            clearTimeout(timer);
            socket.destroy();
            resolve(true);
        });
        socket.on('error', (err) => {
            console.error(`[Redis Availability] Error connecting to ${host}:${port}: ${err.message}`);
            clearTimeout(timer);
            resolve(false);
        });
    });
};
