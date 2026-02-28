import { ConnectionOptions } from 'bullmq';
import * as net from 'net';

/**
 * BullMQ 5 bundles its own ioredis internally.
 * Pass a plain ConnectionOptions object — do NOT pass a standalone ioredis instance.
 * `maxRetriesPerRequest: null` is mandatory for BullMQ blocking commands.
 */
export const redisConnectionOptions: ConnectionOptions = {
    host:     process.env.REDIS_HOST || '127.0.0.1',
    port:     parseInt(process.env.REDIS_PORT  || '6379', 10),
    password: process.env.REDIS_PASSWORD || undefined,
    // Required by BullMQ — disables ioredis request timeout for blocking calls
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
    // Limit reconnection attempts so we don't spam the console when Redis is absent
    retryStrategy: (times: number) => {
        if (times > 3) return null; // stop retrying after 3 attempts
        return Math.min(times * 1000, 5000);
    },
};

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
