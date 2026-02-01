require('dotenv').config();
const mongoose = require('mongoose');

const clearDatabase = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGO_URI, {
            serverApi: {
                version: '1',
                strict: true,
                deprecationErrors: true,
            }
        });
        console.log(`✅ Connected to MongoDB: ${conn.connection.name}`);

        // Clear Users
        await mongoose.connection.collection('users').deleteMany({});
        console.log('🗑️  Cleared users collection');

        // Clear Families (if exists)
        try {
            await mongoose.connection.collection('families').deleteMany({});
            console.log('🗑️  Cleared families collection');
        } catch (e) {
            console.log('ℹ️  Families collection might not exist yet');
        }

        console.log('✨ Database cleared for fresh start');
        await mongoose.connection.close();
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
};

clearDatabase();
