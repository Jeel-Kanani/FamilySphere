const mongoose = require('mongoose');
const fs = require('fs');
require('dotenv').config();

async function checkDocs() {
    try {
        await mongoose.connect(process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/familysphere');
        let output = 'Connected to MongoDB\n';

        const docs = await mongoose.connection.db.collection('documents').find({}).toArray();
        output += `Total Documents: ${docs.length}\n`;
        output += `Documents:\n${JSON.stringify(docs, null, 2)}\n`;

        const families = await mongoose.connection.db.collection('families').find({}).toArray();
        output += `Families:\n${JSON.stringify(families, null, 2)}\n`;

        fs.writeFileSync('db-output-utf8.txt', output, 'utf8');
        console.log('Output written to db-output-utf8.txt');

        await mongoose.disconnect();
    } catch (err) {
        console.error(err);
    }
}

checkDocs();
