import express from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import helmet from 'helmet';
import connectDB from './config/db';
import authRoutes from './routes/authRoutes';
import familyRoutes from './routes/familyRoutes';

dotenv.config();

connectDB();

const app = express();

app.use(cors());
app.use(helmet());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/families', familyRoutes);

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
