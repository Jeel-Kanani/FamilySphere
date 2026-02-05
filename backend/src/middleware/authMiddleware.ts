import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import User, { IUser } from '../models/User';

export interface AuthRequest extends Request {
    user?: IUser | null;
}

const protect = async (req: AuthRequest, res: Response, next: NextFunction) => {
    let token;

    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
        try {
            token = req.headers.authorization.split(' ')[1];
            const jwtSecret = process.env.JWT_SECRET;
            if (!jwtSecret) {
                console.error('JWT_SECRET not set');
                return res.status(500).json({ message: 'Server configuration error' });
            }
            const decoded: any = jwt.verify(token, jwtSecret);

            const user = await User.findById(decoded.id).select('-password');
            if (!user) {
                return res.status(401).json({ message: 'Not authorized, user not found' });
            }

            const decodedVersion = typeof decoded.ver === 'number' ? decoded.ver : 0;
            const currentVersion = user.tokenVersion ?? 0;
            if (decodedVersion !== currentVersion) {
                return res.status(401).json({ message: 'Not authorized, token revoked' });
            }

            req.user = user;
            return next();
        } catch (error) {
            console.error(error);
            return res.status(401).json({ message: 'Not authorized, token failed' });
        }
    }

    if (!token) {
        return res.status(401).json({ message: 'Not authorized, no token' });
    }
};

export { protect };
