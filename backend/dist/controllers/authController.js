"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.googleAuth = exports.logoutUser = exports.updateProfile = exports.getCurrentUser = exports.loginUser = exports.registerUser = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const crypto_1 = __importDefault(require("crypto"));
const google_auth_library_1 = require("google-auth-library");
const User_1 = __importDefault(require("../models/User"));
// Generate JWT
const generateToken = (user) => {
    var _a;
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
        throw new Error('JWT_SECRET is not set in environment');
    }
    return jsonwebtoken_1.default.sign({ id: user._id, ver: (_a = user.tokenVersion) !== null && _a !== void 0 ? _a : 0 }, jwtSecret, {
        expiresIn: '30d',
    });
};
const normalizeEmail = (email) => email.trim().toLowerCase();
const isValidEmail = (email) => {
    // Simple, fast sanity check for common formats
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
};
const getGoogleClientIds = () => {
    return (process.env.GOOGLE_CLIENT_IDS || process.env.GOOGLE_CLIENT_ID || '')
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean);
};
// @desc    Register new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
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
        const userExists = yield User_1.default.findOne({ email: normalizedEmail });
        if (userExists) {
            return res.status(400).json({ message: 'User already exists' });
        }
        const user = yield User_1.default.create({
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
        }
        else {
            res.status(400).json({ message: 'Invalid user data' });
        }
    }
    catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});
exports.registerUser = registerUser;
// @desc    Authenticate a user
// @route   POST /api/auth/login
// @access  Public
const loginUser = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const { email, password } = req.body;
    try {
        if (!email || !password) {
            return res.status(400).json({ message: 'Email and password are required' });
        }
        if (typeof email !== 'string' || !isValidEmail(email)) {
            return res.status(400).json({ message: 'Invalid email address' });
        }
        const normalizedEmail = normalizeEmail(email);
        const user = yield User_1.default.findOne({ email: normalizedEmail });
        if (user && (yield user.matchPassword(password))) {
            res.json({
                _id: user._id,
                name: user.name,
                email: user.email,
                familyId: user.familyId,
                role: user.role,
                token: generateToken(user),
            });
        }
        else {
            res.status(401).json({ message: 'Invalid email or password' });
        }
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.loginUser = loginUser;
// @desc    Get current user profile
// @route   GET /api/auth/me
// @access  Private
const getCurrentUser = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
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
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.getCurrentUser = getCurrentUser;
// @desc    Update user profile
// @route   PUT /api/auth/profile
// @access  Private
const updateProfile = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a._id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        const user = yield User_1.default.findById(userId);
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
            const existing = yield User_1.default.findOne({ email: normalizedEmail, _id: { $ne: user._id } });
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
        const updatedUser = yield user.save();
        res.json({
            _id: updatedUser._id,
            name: updatedUser.name,
            email: updatedUser.email,
            familyId: updatedUser.familyId,
            role: updatedUser.role,
        });
    }
    catch (error) {
        res.status(500).json({ message: error.message });
    }
});
exports.updateProfile = updateProfile;
// @desc    Logout a user (invalidate tokens)
// @route   POST /api/auth/logout
// @access  Private
const logoutUser = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    try {
        const userId = (_a = req.user) === null || _a === void 0 ? void 0 : _a._id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }
        yield User_1.default.findByIdAndUpdate(userId, { $inc: { tokenVersion: 1 } });
        return res.json({ message: 'Logged out' });
    }
    catch (error) {
        return res.status(500).json({ message: error.message });
    }
});
exports.logoutUser = logoutUser;
// @desc    Login/Register with Google
// @route   POST /api/auth/google
// @access  Public
const googleAuth = (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const googleClientIds = getGoogleClientIds();
        if (googleClientIds.length === 0) {
            return res.status(500).json({ message: 'Google auth not configured' });
        }
        const googleClient = new google_auth_library_1.OAuth2Client(googleClientIds[0]);
        const { idToken } = req.body;
        if (!idToken || typeof idToken !== 'string') {
            return res.status(400).json({ message: 'idToken is required' });
        }
        const ticket = yield googleClient.verifyIdToken({
            idToken,
            audience: googleClientIds,
        });
        const payload = ticket.getPayload();
        if (!(payload === null || payload === void 0 ? void 0 : payload.email)) {
            return res.status(401).json({ message: 'Invalid Google token' });
        }
        const email = normalizeEmail(payload.email);
        const name = payload.name || email.split('@')[0];
        let user = yield User_1.default.findOne({ email });
        if (!user) {
            const randomPassword = crypto_1.default.randomBytes(32).toString('hex');
            user = yield User_1.default.create({
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
    }
    catch (error) {
        const msg = typeof (error === null || error === void 0 ? void 0 : error.message) === 'string' ? error.message : 'Google auth failed';
        if (msg.toLowerCase().includes('audience') || msg.toLowerCase().includes('invalid')) {
            return res.status(401).json({ message: 'Invalid Google token audience' });
        }
        return res.status(500).json({ message: msg });
    }
});
exports.googleAuth = googleAuth;
