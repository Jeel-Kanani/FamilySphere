// Quick script to check MongoDB connection and view users
require('dotenv').config();
const mongoose = require('mongoose');

const checkDatabase = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGO_URI);
        console.log(`✅ Connected to MongoDB successfully! Host: ${conn.connection.host}`);
        console.log(`📊 Database: ${conn.connection.name}\n`);

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
