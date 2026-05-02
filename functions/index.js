// Load .env only in development (local machine)
if (process.env.NODE_ENV !== 'production') {
  require('dotenv').config();
}

const express = require('express');
const cors = require('cors');

const billingRouter = require('./src/billing');
const usersRouter   = require('./src/users');
const tripsRouter   = require('./src/trips');
const reportsRouter = require('./src/reports');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/billing', billingRouter);
app.use('/users',   usersRouter);
app.use('/trips',   tripsRouter);
app.use('/reports', reportsRouter);

app.get('/health', (_req, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));

// ── Standalone (dev local) ────────────────────────────────────────────────────
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  const server = app.listen(PORT, () => {
    console.log(`[TrackingVelocidade API] Listening on port ${PORT}`);
    console.log(`[TrackingVelocidade API] Environment: ${process.env.NODE_ENV || 'development'}`);
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('[TrackingVelocidade API] SIGTERM signal received: closing HTTP server');
    server.close(() => {
      console.log('[TrackingVelocidade API] HTTP server closed');
      process.exit(0);
    });
  });
}

// ── Firebase Cloud Functions export ──────────────────────────────────────────
const functions = require('firebase-functions');
exports.api = functions.https.onRequest(app);
