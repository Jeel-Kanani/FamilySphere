const mongoose = require('mongoose');
require('dotenv').config();

async function checkConnection() {
  const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!uri) {
    console.error('MONGO_URI or MONGODB_URI must be set in environment');
    process.exit(1);
  }

  try {
    await mongoose.connect(uri);
    const admin = mongoose.connection.db.admin();
    const ping = await admin.ping();
    console.log('MongoDB connection OK. Ping:', ping);
    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error('MongoDB connection failed:', err.message || err);
    process.exit(1);
  }
}

checkConnection();
