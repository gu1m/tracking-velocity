const { Router } = require('express');
const {
  createTrip,
  endTrip,
  listTrips,
  getTripWithRecords,
  deleteTrip,
  insertSpeedRecords,
} = require('./db');
const { verifyFirebaseToken } = require('./auth');

const router = Router();

// ── POST /trips ───────────────────────────────────────────────────────────────
// Abre uma nova viagem. Chamado quando o app detecta speed > 10 km/h após inatividade.
router.post('/', verifyFirebaseToken, async (req, res) => {
  const { id, startedAt, startAddress } = req.body;
  if (!id || !startedAt) return res.status(400).json({ error: 'id e startedAt são obrigatórios.' });

  try {
    const trip = await createTrip(req.user.uid, { id, startedAt, startAddress });
    res.status(201).json(trip);
  } catch (err) {
    console.error('[POST /trips]', err.message);
    res.status(500).json({ error: 'Não foi possível criar a viagem.' });
  }
});

// ── PUT /trips/:id/end ────────────────────────────────────────────────────────
// Fecha a viagem com métricas finais.
router.put('/:id/end', verifyFirebaseToken, async (req, res) => {
  const { endedAt, avgSpeedKmh, maxSpeedKmh, distanceKm, endAddress } = req.body;
  try {
    const trip = await endTrip(req.params.id, {
      endedAt, avgSpeedKmh, maxSpeedKmh, distanceKm, endAddress,
    });
    res.json(trip);
  } catch (err) {
    console.error('[PUT /trips/:id/end]', err.message);
    res.status(500).json({ error: 'Não foi possível encerrar a viagem.' });
  }
});

// ── POST /trips/:id/records ───────────────────────────────────────────────────
// Batch insert de SpeedRecords (até 100 por chamada para economizar banda).
router.post('/:id/records', verifyFirebaseToken, async (req, res) => {
  const { records } = req.body; // Array de SpeedRecord
  if (!Array.isArray(records) || records.length === 0) {
    return res.status(400).json({ error: 'records deve ser um array não-vazio.' });
  }
  if (records.length > 100) {
    return res.status(400).json({ error: 'Máximo de 100 records por chamada.' });
  }

  const enriched = records.map((r) => ({
    ...r,
    tripId: req.params.id,
    userId: req.user.uid,
  }));

  try {
    await insertSpeedRecords(enriched);
    res.status(201).json({ inserted: enriched.length });
  } catch (err) {
    console.error('[POST /trips/:id/records]', err.message);
    res.status(500).json({ error: 'Erro ao salvar registros.' });
  }
});

// ── GET /trips ────────────────────────────────────────────────────────────────
// Lista viagens do usuário, paginadas.
router.get('/', verifyFirebaseToken, async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit ?? '20', 10), 100);
  const offset = parseInt(req.query.offset ?? '0', 10);
  try {
    const trips = await listTrips(req.user.uid, { limit, offset });
    res.json(trips);
  } catch (err) {
    console.error('[GET /trips]', err.message);
    res.status(500).json({ error: 'Erro ao listar viagens.' });
  }
});

// ── GET /trips/:id ────────────────────────────────────────────────────────────
// Detalhe da viagem com todos os SpeedRecords.
router.get('/:id', verifyFirebaseToken, async (req, res) => {
  try {
    const { trip, records } = await getTripWithRecords(req.params.id, req.user.uid);
    res.json({ ...trip, records });
  } catch (err) {
    console.error('[GET /trips/:id]', err.message);
    res.status(500).json({ error: 'Viagem não encontrada.' });
  }
});

// ── DELETE /trips/:id ─────────────────────────────────────────────────────────
router.delete('/:id', verifyFirebaseToken, async (req, res) => {
  try {
    await deleteTrip(req.params.id, req.user.uid);
    res.json({ success: true });
  } catch (err) {
    console.error('[DELETE /trips/:id]', err.message);
    res.status(500).json({ error: 'Erro ao excluir viagem.' });
  }
});

module.exports = router;
