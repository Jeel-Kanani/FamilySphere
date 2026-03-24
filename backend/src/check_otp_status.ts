import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/familysphere';

async function checkOtp() {
    try {
        await mongoose.connect(MONGO_URI);
        const db = mongoose.connection.db;
        if (!db) throw new Error('DB not found');
        const collection = db.collection('emailotps');
        const record = await collection.findOne({ email: 'test-agent-123@example.com' });

        if (record) {
            console.log('OTP Record:', JSON.stringify(record, null, 2));
        } else {
            console.log('OTP record does not exist');
        }

        await mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

checkOtp();
