"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const dotenv_1 = __importDefault(require("dotenv"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const morgan_1 = __importDefault(require("morgan"));
const db_1 = __importDefault(require("./config/db"));
const authRoutes_1 = __importDefault(require("./routes/authRoutes"));
const familyRoutes_1 = __importDefault(require("./routes/familyRoutes"));
const documentRoutes_1 = __importDefault(require("./routes/documentRoutes"));
dotenv_1.default.config();
(0, db_1.default)();
const app = (0, express_1.default)();
app.use((req, res, next) => {
    console.log(`[GLOBAL LOG] ${req.method} ${req.url}`);
    next();
});
app.use((0, morgan_1.default)('dev'));
app.use((0, cors_1.default)());
app.use((0, helmet_1.default)());
app.use(express_1.default.json());
app.use('/api/auth', authRoutes_1.default);
app.use('/api/families', familyRoutes_1.default);
app.use('/api/documents', documentRoutes_1.default);
const PORT = process.env.PORT || 5000;
app.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`Server running on all interfaces at port ${PORT}`);
});
