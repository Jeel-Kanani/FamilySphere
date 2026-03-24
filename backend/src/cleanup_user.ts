import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/familysphere';

async function checkUser() {
    try {
        await mongoose.connect(MONGO_URI);
        const db = mongoose.connection.db;
        if (!db) throw new Error('DB not found');
        const collection = db.collection('users');
        const user = await collection.findOne({ email: 'test-agent-123@example.com' });

        if (user) {
            console.log('User Exists:', JSON.stringify(user, null, 2));
            // Delete it to allow re-registration test
            await collection.deleteOne({ _id: user._id });
            console.log('User deleted for cleanup');
        } else {
            console.log('User does not exist');
        }

        await mongoose.disconnect();
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

checkUser();
