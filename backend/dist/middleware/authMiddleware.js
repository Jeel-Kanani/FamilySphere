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
exports.protect = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const User_1 = __importDefault(require("../models/User"));
const protect = (req, res, next) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    let token;
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
        try {
            token = req.headers.authorization.split(' ')[1];
            const jwtSecret = process.env.JWT_SECRET;
            if (!jwtSecret) {
                console.error('JWT_SECRET not set');
                return res.status(500).json({ message: 'Server configuration error' });
            }
            const decoded = jsonwebtoken_1.default.verify(token, jwtSecret);
            const user = yield User_1.default.findById(decoded.id).select('-password');
            if (!user) {
                return res.status(401).json({ message: 'Not authorized, user not found' });
            }
            const decodedVersion = typeof decoded.ver === 'number' ? decoded.ver : 0;
            const currentVersion = (_a = user.tokenVersion) !== null && _a !== void 0 ? _a : 0;
            if (decodedVersion !== currentVersion) {
                return res.status(401).json({ message: 'Not authorized, token revoked' });
            }
            req.user = user;
            return next();
        }
        catch (error) {
            console.error(error);
            return res.status(401).json({ message: 'Not authorized, token failed' });
        }
    }
    if (!token) {
        return res.status(401).json({ message: 'Not authorized, no token' });
    }
});
exports.protect = protect;
