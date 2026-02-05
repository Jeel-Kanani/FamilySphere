import { Response } from 'express';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import User, { IUser } from '../models/User';
import { AuthRequest } from '../middleware/authMiddleware';
import EmailOtp from '../models/EmailOtp';
import { sendEmailOtp } from '../services/emailService';

// Generate JWT
const generateToken = (user: Pick<IUser, '_id' | 'tokenVersion'>) => {
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
        throw new Error('JWT_SECRET is not set in environment');
    }
    return jwt.sign({ id: user._id, ver: user.tokenVersion ?? 0 }, jwtSecret, {
        expiresIn: '30d',
    });
};

const normalizeEmail = (email: string) => email.trim().toLowerCase();

const isValidEmail = (email: string) => {
    // Simple, fast sanity check for common formats
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
};

const otpSecret = process.env.OTP_SECRET || process.env.JWT_SECRET || 'otp_secret';
const hashOtp = (email: string, code: string) => {
    return crypto.createHash('sha256').update(`${email}:${code}:${otpSecret}`).digest('hex');
};

const generateOtp = () => {
    return Math.floor(100000 + Math.random() * 900000).toString();
};

const getGoogleClientIds = () => {
    return (process.env.GOOGLE_CLIENT_IDS || process.env.GOOGLE_CLIENT_ID || '')
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean);
};

// @desc    Send email OTP for registration
// @route   POST /api/auth/send-email-otp
// @access  Public
const sendEmailOtpController = async (req: AuthRequest, res: Response) => {
    const { email } = req.body;

    try {
        if (!email || typeof email !== 'string' || !isValidEmail(email)) {
            return res.status(400).json({ message: 'Invalid email address' });
        }

        const normalizedEmail = normalizeEmail(email);
        const userExists = await User.findOne({ email: normalizedEmail });
        if (userExists) {
            return res.status(400).json({ message: 'User already exists' });
        }

        const now = new Date();
        const existing = await EmailOtp.findOne({ email: normalizedEmail });
        if (existing && existing.lastSentAt) {
            const secondsSinceLastSend = (now.getTime() - existing.lastSentAt.getTime()) / 1000;
            if (secondsSinceLastSend < 30) {
                return res.status(429).json({ message: 'Please wait before requesting another code' });
            }
        }

        const code = generateOtp();
        const expiresAt = new Date(now.getTime() + 10 * 60 * 1000);
        const codeHash = hashOtp(normalizedEmail, code);

        await EmailOtp.findOneAndUpdate(
            { email: normalizedEmail },
            {
                email: normalizedEmail,
                codeHash,
                expiresAt,
                verifiedAt: null,
                attempts: 0,
                lastSentAt: now,
            },
            { upsert: true, new: true },
        );

        await sendEmailOtp(normalizedEmail, code);

        const response: Record<string, unknown> = { message: 'OTP sent to email' };
        if (process.env.NODE_ENV !== 'production') {
            response.devOtp = code;
        }

        return res.json(response);
    } catch (error: any) {
        return res.status(500).json({ message: error.message || 'Server error' });
    }
};

// @desc    Verify email OTP for registration
// @route   POST /api/auth/verify-email-otp
// @access  Public
const verifyEmailOtpController = async (req: AuthRequest, res: Response) => {
    const { email, otp } = req.body;

    try {
        if (!email || typeof email !== 'string' || !isValidEmail(email)) {
            return res.status(400).json({ message: 'Invalid email address' });
        }
        if (!otp || typeof otp !== 'string' || otp.length < 4) {
            return res.status(400).json({ message: 'Invalid OTP' });
        }

        const normalizedEmail = normalizeEmail(email);
        const record = await EmailOtp.findOne({ email: normalizedEmail });
        if (!record) {
            return res.status(400).json({ message: 'OTP not found or expired' });
        }

        if (record.expiresAt.getTime() < Date.now()) {
            await EmailOtp.deleteOne({ _id: record._id });
            return res.status(400).json({ message: 'OTP expired' });
        }

        if (record.attempts >= 5) {
            return res.status(429).json({ message: 'Too many attempts. Please request a new code.' });
        }

        const incomingHash = hashOtp(normalizedEmail, otp);
        if (incomingHash !== record.codeHash) {
            record.attempts += 1;
            await record.save();
            return res.status(400).json({ message: 'Invalid OTP' });
        }

        record.verifiedAt = new Date();
        await record.save();

        return res.json({ message: 'OTP verified' });
    } catch (error: any) {
        return res.status(500).json({ message: error.message || 'Server error' });
    }
};

// @desc    Register new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req: AuthRequest, res: Response) => {
    const { name, email, password } = req.body;

    try {
        if (!name || !email || !password) {
            return res.status(400).json({ message: 'Name, email, and password are required' });
        }

        if (typeof name !== 'string' || name.trim().length < 2) {
            return res.status(400).json({ message: 'Name must be at least 2 characters long' });
        }

        if (typeof email !== 'string' || !isValidEmail(email)) {
            return res.status(400).json({ message: 'Invalid email address' });
        }

        if (typeof password !== 'string' || password.length < 8) {
            return res.status(400).json({ message: 'Password must be at least 8 characters long' });
        }

        const normalizedEmail = normalizeEmail(email);

        const userExists = await User.findOne({ email: normalizedEmail });

        if (userExists) {
            return res.status(400).json({ message: 'User already exists' });
        }

        const otpRecord = await EmailOtp.findOne({ email: normalizedEmail });
        if (!otpRecord || !otpRecord.verifiedAt || otpRecord.expiresAt.getTime() < Date.now()) {
            return res.status(400).json({ message: 'Email not verified' });
        }

        const user = await User.create({
            name: name.trim(),
            email: normalizedEmail,
            password,
        });

        if (user) {
            res.status(201).json({
                _id: user._id,
                name: user.name,
                email: user.email,
                familyId: user.familyId,
                role: user.role,
                token: generateToken(user),
            });
            await EmailOtp.deleteOne({ _id: otpRecord._id });
        } else {
            res.status(400).json({ message: 'Invalid user data' });
        }
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

// @desc    Authenticate a user
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req: AuthRequest, res: Response) => {
    const { email, password } = req.body;

    try {
        if (!email || !password) {
            return res.status(400).json({ message: 'Email and password are required' });
        }

        if (typeof email !== 'string' || !isValidEmail(email)) {
            return res.status(400).json({ message: 'Invalid email address' });
        }

        const normalizedEmail = normalizeEmail(email);
        const user = await User.findOne({ email: normalizedEmail });

        if (user && (await user.matchPassword(password))) {
            res.json({
                _id: user._id,
                name: user.name,
                email: user.email,
                familyId: user.familyId,
                role: user.role,
                token: generateToken(user),
            });
        } else {
            res.status(401).json({ message: 'Invalid email or password' });
        }
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// @desc    Get current user profile
// @route   GET /api/auth/me
// @access  Private
const getCurrentUser = async (req: AuthRequest, res: Response) => {
    try {
        const user = req.user;
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        res.json({
            _id: user._id,
            name: user.name,
            email: user.email,
            familyId: user.familyId,
            role: user.role,
        });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// @desc    Update user profile
// @route   PUT /api/auth/profile
// @access  Private
const updateProfile = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?._id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        const user = await User.findById(userId);

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Update fields
        if (req.body.name) {
            if (typeof req.body.name !== 'string' || req.body.name.trim().length < 2) {
                return res.status(400).json({ message: 'Name must be at least 2 characters long' });
            }
            user.name = req.body.name.trim();
        }

        if (req.body.email) {
            if (typeof req.body.email !== 'string' || !isValidEmail(req.body.email)) {
                return res.status(400).json({ message: 'Invalid email address' });
            }
            const normalizedEmail = normalizeEmail(req.body.email);
            const existing = await User.findOne({ email: normalizedEmail, _id: { $ne: user._id } });
            if (existing) {
                return res.status(400).json({ message: 'Email already in use' });
            }
            user.email = normalizedEmail;
        }

        if (req.body.password) {
            if (typeof req.body.password !== 'string' || req.body.password.length < 8) {
                return res.status(400).json({ message: 'Password must be at least 8 characters long' });
            }
            user.password = req.body.password;
        }

        const updatedUser = await user.save();

        res.json({
            _id: updatedUser._id,
            name: updatedUser.name,
            email: updatedUser.email,
            familyId: updatedUser.familyId,
            role: updatedUser.role,
        });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
};

// @desc    Logout a user (invalidate tokens)
// @route   POST /api/auth/logout
// @access  Private
const logoutUser = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?._id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        await User.findByIdAndUpdate(userId, { $inc: { tokenVersion: 1 } });
        return res.json({ message: 'Logged out' });
    } catch (error: any) {
        return res.status(500).json({ message: error.message });
    }
};

// @desc    Login/Register with Google
// @route   POST /api/auth/google
// @access  Public
const googleAuth = async (req: AuthRequest, res: Response) => {
    try {
        const googleClientIds = getGoogleClientIds();
        if (googleClientIds.length === 0) {
            return res.status(500).json({ message: 'Google auth not configured' });
        }
        const googleClient = new OAuth2Client(googleClientIds[0]);

        const { idToken } = req.body;
        if (!idToken || typeof idToken !== 'string') {
            return res.status(400).json({ message: 'idToken is required' });
        }

        const ticket = await googleClient.verifyIdToken({
            idToken,
            audience: googleClientIds,
        });

        const payload = ticket.getPayload();
        if (!payload?.email) {
            return res.status(401).json({ message: 'Invalid Google token' });
        }

        const email = normalizeEmail(payload.email);
        const name = payload.name || email.split('@')[0];

        let user = await User.findOne({ email });
        if (!user) {
            const randomPassword = crypto.randomBytes(32).toString('hex');
            user = await User.create({
                name,
                email,
                password: randomPassword,
            });
        }

        return res.json({
            _id: user._id,
            name: user.name,
            email: user.email,
            familyId: user.familyId,
            role: user.role,
            token: generateToken(user),
        });
    } catch (error: any) {
        const msg = typeof error?.message === 'string' ? error.message : 'Google auth failed';
        if (msg.toLowerCase().includes('audience') || msg.toLowerCase().includes('invalid')) {
            return res.status(401).json({ message: 'Invalid Google token audience' });
        }
        return res.status(500).json({ message: msg });
    }
};

export {
    registerUser,
    loginUser,
    getCurrentUser,
    updateProfile,
    logoutUser,
    googleAuth,
    sendEmailOtpController,
    verifyEmailOtpController,
};
