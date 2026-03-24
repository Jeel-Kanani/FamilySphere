import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import crypto from 'crypto';

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/familysphere';
const otpSecret = process.env.OTP_SECRET || process.env.JWT_SECRET || 'otp_secret';

const hashOtp = (email: string, code: string) => {
    return crypto.createHash('sha256').update(`${email}:${code}:${otpSecret}`).digest('hex');
};

async function findOtp() {
    try {
        await mongoose.connect(MONGO_URI);
        const db = mongoose.connection.db;
        if (!db) throw new Error('DB not found');
        const collection = db.collection('emailotps');
        const latest = await collection.findOne({ email: 'test-agent-123@example.com' });

        if (!latest) {
            console.log('No OTP record found for test-agent-123@example.com');
            process.exit(1);
        }

        const targetHash = latest.codeHash;
        const email = latest.email;

        console.log(`Brute-forcing OTP for ${email} with hash ${targetHash}...`);

        for (let i = 100000; i <= 999999; i++) {
            const code = i.toString();
            if (hashOtp(email, code) === targetHash) {
                console.log(`FOUND OTP: ${code}`);
                await mongoose.disconnect();
                return;
            }
        }

        console.log('OTP not found after brute-force');
        await mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

findOtp();
