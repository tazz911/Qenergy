// backend/index.js
const express = require('express');
const admin   = require('firebase-admin');


const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

//  Express setup 
const app = express();
app.use(express.json());

// Allow requests from the Flutter app (adjust origin in production)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

//  Routes 
const authRoutes = require('./auth');
app.use('/api/auth', authRoutes);

app.get('/health', (_, res) => res.json({ status: 'ok' }));

//  Start server 
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`EnergyIQ backend running on port ${PORT}`));
