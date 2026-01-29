// Quick script to check MongoDB connection and view users
const mongoose = require('mongoose');

const MONGO_URI = 'mongodb://127.0.0.1:27017/familysphere';

async function checkDatabase() {
    try {
        // Connect to MongoDB
        await mongoose.connect(MONGO_URI);
        console.log('✅ Connected to MongoDB successfully!');
        console.log('📊 Database: familysphere\n');

        // Get all collections
        const collections = await mongoose.connection.db.listCollections().toArray();
        console.log('📁 Collections found:', collections.map(c => c.name).join(', '));
        console.log('');

        // Check users collection
        const usersCollection = mongoose.connection.db.collection('users');
        const userCount = await usersCollection.countDocuments();
        console.log(`👥 Total users: ${userCount}`);

        if (userCount > 0) {
            console.log('\n📋 Registered Users:');
            const users = await usersCollection.find({}).toArray();
            users.forEach((user, index) => {
                console.log(`\n${index + 1}. User:`);
                console.log(`   ID: ${user._id}`);
                console.log(`   Name: ${user.name}`);
                console.log(`   Email: ${user.email}`);
                console.log(`   Family ID: ${user.familyId || 'None'}`);
                console.log(`   Role: ${user.role || 'N/A'}`);
                console.log(`   Created: ${user.createdAt}`);
            });
        }

        await mongoose.connection.close();
        console.log('\n✅ Database check complete!');
    } catch (error) {
        console.error('❌ Error:', error.message);
        if (error.message.includes('ECONNREFUSED')) {
            console.log('\n⚠️  MongoDB is not running!');
            console.log('Please start MongoDB with: net start MongoDB');
        }
    }
}

checkDatabase();
