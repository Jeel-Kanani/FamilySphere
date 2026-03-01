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
        const parsed = new URL(url);
        return {
            host:     parsed.hostname,
            port:     parseInt(parsed.port || '6379', 10),
            password: parsed.password || undefined,
            username: parsed.username || undefined,
            maxRetriesPerRequest: null,
            enableReadyCheck: false,
            retryStrategy: () => null,
        };
    }
    return {
        host:     process.env.REDIS_HOST || '127.0.0.1',
        port:     parseInt(process.env.REDIS_PORT  || '6379', 10),
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
        const timer = setTimeout(() => { socket.destroy(); resolve(false); }, 2000);
        socket.on('connect', () => { clearTimeout(timer); socket.destroy(); resolve(true); });
        socket.on('error',   () => { clearTimeout(timer); resolve(false); });
    });
};
