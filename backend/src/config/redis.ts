import { ConnectionOptions } from 'bullmq';
import * as net from 'net';

/**
 * BullMQ 5 bundles its own ioredis internally.
 * Supports either REDIS_URL (full URL — what Render provides) or
 * individual REDIS_HOST / REDIS_PORT / REDIS_PASSWORD env vars.
 */
const buildConnectionOptions = (): ConnectionOptions => {
    const rawUrl = process.env.REDIS_URL;
    if (rawUrl) {
        const urlString = rawUrl.trim();
        console.log('[Redis Config] Using REDIS_URL from environment');
        try {
            const parsed = new URL(urlString);
            return {
                host: parsed.hostname,
                port: parseInt(parsed.port || '6379', 10),
                password: parsed.password || undefined,
                username: parsed.username || undefined,
                maxRetriesPerRequest: null,
                enableReadyCheck: false,
                retryStrategy: () => null,
            };
        } catch (e) {
            console.error('[Redis Config] Failed to parse REDIS_URL. Falling back to default.');
        }
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
export const isRedisAvailable = (checkHost?: string): Promise<boolean> => {
    return new Promise((resolve) => {
        const host = checkHost || (redisConnectionOptions as any).host || '127.0.0.1';
        const port = (redisConnectionOptions as any).port || 6379;

        const socket = net.createConnection({ host, port, family: 4 }); // Force IPv4 for cloud stability
        const timeoutMs = 5000;

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

            // Fallback: If it's a Render internal host without suffix, try adding .internal
            if (host.startsWith('red-') && !host.includes('.') && !checkHost) {
                console.log(`[Redis Availability] Retrying with .internal suffix for Render...`);
                resolve(isRedisAvailable(`${host}.internal`));
            } else {
                resolve(false);
            }
        });
    });
};

/**
 * Retries the availability check multiple times.
 * Useful for cloud environments where DNS or services might take a few seconds to wake up.
 */
export const checkRedisWithRetries = async (maxAttempts = 5, delayMs = 3000): Promise<boolean> => {
    for (let i = 1; i <= maxAttempts; i++) {
        console.log(`[Redis Check] Attempt ${i}/${maxAttempts}...`);
        const available = await isRedisAvailable();
        if (available) return true;

        if (i < maxAttempts) {
            console.log(`[Redis Check] Failed. Retrying in ${delayMs / 1000}s...`);
            await new Promise(resolve => setTimeout(resolve, delayMs));
        }
    }
    return false;
};
