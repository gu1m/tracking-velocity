const { Router } = require('express');
const { getOrCreateUser, deleteUser } = require('./db');
const { verifyFirebaseToken } = require('./auth');
const { admin } = require('./firebase'); // usa instância já inicializada

const router = Router();

// ── GET /users/me ─────────────────────────────────────────────────────────────
// Retorna status de assinatura do usuário autenticado.
// Cria o registro na primeira vez (onboarding).
router.get('/me', verifyFirebaseToken, async (req, res) => {
  try {
    const user = await getOrCreateUser(req.user.uid, req.user.email ?? null);
    res.json({
      uid: req.user.uid,
      status: user.subscription_status,
      renewsAt: user.subscription_renews_at ?? null,
      preapprovalId: user.preapproval_id ?? null,
    });
  } catch (err) {
    console.error('[GET /users/me]', err.message);
    res.status(500).json({ error: 'Erro ao buscar dados do usuário.' });
  }
});

// ── DELETE /users/me ──────────────────────────────────────────────────────────
// Exclui conta + todos os dados (LGPD Art. 18).
router.delete('/me', verifyFirebaseToken, async (req, res) => {
  const uid = req.user.uid;
  try {
    // Exclui do Supabase (trips e speed_records em cascata).
    await deleteUser(uid);
    // Exclui do Firebase Auth.
    await admin.auth().deleteUser(uid);
    res.json({ success: true });
  } catch (err) {
    console.error('[DELETE /users/me]', err.message);
    res.status(500).json({ error: 'Não foi possível excluir a conta.' });
  }
});

module.exports = router;
