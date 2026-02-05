import express from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import connectDB from './config/db';
import authRoutes from './routes/authRoutes';
import familyRoutes from './routes/familyRoutes';
import documentRoutes from './routes/documentRoutes';

dotenv.config();

connectDB();

const app = express();

app.use((req, res, next) => {
    console.log(`[GLOBAL LOG] ${req.method} ${req.url}`);
    next();
});

app.use(morgan('dev'));
app.use(cors());
app.use(helmet());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/families', familyRoutes);
app.use('/api/documents', documentRoutes);

const PORT = process.env.PORT || 5000;

app.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`Server running on all interfaces at port ${PORT}`);
});
