import { Server } from 'socket.io';
import { Server as HttpServer } from 'http';

let io: Server;

export const initSocket = (server: HttpServer) => {
  const allowedOrigins = [
    'http://localhost:3000',
    'http://localhost:5173',
    'https://familysphere.onrender.com',
    process.env.FRONTEND_URL,
  ].filter(Boolean);

  io = new Server(server, {
    cors: {
      origin: (origin, callback) => {
        if (!origin) return callback(null, true);
        if (allowedOrigins.includes(origin) || origin?.includes('localhost')) {
          callback(null, true);
        } else {
          callback(null, true); // Allow all for now
        }
      },
      methods: ['GET', 'POST'],
      credentials: true,
    },
  });

  io.on('connection', (socket) => {
    console.log(`[Socket] User connected: ${socket.id}`);

    // Join a specific family room to receive targeted updates
    socket.on('join_family', (familyId: string) => {
      if (familyId) {
        socket.join(familyId);
        console.log(`[Socket] User ${socket.id} joined family room: ${familyId}`);
      }
    });

    // Leave family room
    socket.on('leave_family', (familyId: string) => {
      if (familyId) {
        socket.leave(familyId);
        console.log(`[Socket] User ${socket.id} left family room: ${familyId}`);
      }
    });

    socket.on('disconnect', () => {
      console.log(`[Socket] User disconnected: ${socket.id}`);
    });
  });

  return io;
};

export const getIO = () => {
  if (!io) {
    throw new Error('Socket.io not initialized!');
  }
  return io;
};

/**
 * Emit an event to all users in a specific family room
 */
export const emitToFamily = (familyId: string, event: string, data: any) => {
  if (io) {
    io.to(familyId).emit(event, data);
    console.log(`[Socket] Emitted ${event} to family ${familyId}`);
  }
};
