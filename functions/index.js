require('dotenv').config();

const express = require('express');
const cors = require('cors');

const billingRouter = require('./src/billing');
const usersRouter  = require('./src/users');
const tripsRouter  = require('./src/trips');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/billing', billingRouter);
app.use('/users',   usersRouter);
app.use('/trips',   tripsRouter);

app.get('/health', (_req, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));

// ── Standalone (dev local) ────────────────────────────────────────────────────
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () =>
    console.log(`[TrackingVelocidade API] http://localhost:${PORT}`)
  );
}

// ── Firebase Cloud Functions export ──────────────────────────────────────────
const functions = require('firebase-functions');
exports.api = functions.https.onRequest(app);
