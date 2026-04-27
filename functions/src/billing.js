const { Router } = require('express');
const { createSubscription, cancelSubscription, getPreapproval } = require('./mercadopago');
const { updateUserSubscription, getUserByEmail } = require('./db');
const { verifyFirebaseToken } = require('./auth');
const { verifyWebhookSignature } = require('./webhook');

const router = Router();

// ── POST /billing/subscribe ──────────────────────────────────────────────────
// Cria uma preapproval no Mercado Pago e retorna a init_point para o app.
// Requer header: Authorization: Bearer <Firebase ID Token>
router.post('/subscribe', verifyFirebaseToken, async (req, res) => {
  const userId = req.user.uid;

  try {
    const { initPoint, preapprovalId } = await createSubscription(userId);
    res.json({ init_point: initPoint, preapproval_id: preapprovalId });
  } catch (err) {
    console.error('[/subscribe] Erro:', err.message);
    res.status(500).json({ error: err.message || 'Não foi possível criar a assinatura.' });
  }
});

// ── POST /billing/cancel ─────────────────────────────────────────────────────
// Cancela a assinatura ativa do usuário.
router.post('/cancel', verifyFirebaseToken, async (req, res) => {
  const userId = req.user.uid;
  const { preapprovalId } = req.body;

  if (!preapprovalId) {
    return res.status(400).json({ error: 'preapprovalId é obrigatório.' });
  }

  try {
    await cancelSubscription(preapprovalId);
    await updateUserSubscription(userId, {
      status: 'canceled',
      preapprovalId,
    });
    res.json({ success: true });
  } catch (err) {
    console.error('[/cancel] Erro:', err.message);
    res.status(500).json({ error: 'Não foi possível cancelar a assinatura.' });
  }
});

// ── POST /billing/webhook ────────────────────────────────────────────────────
// Recebe notificações do Mercado Pago sobre mudanças de status da assinatura.
//
// Segurança: em produção, valide a assinatura do webhook usando o secret
// configurado no painel do MP (Dashboard > Webhooks > Chave secreta).
// A função verifyWebhookSignature lida com o cabeçalho x-signature.
router.post('/webhook', async (req, res) => {
  // Responde 200 imediatamente — o MP requer resposta em < 5 s.
  res.sendStatus(200);

  const { type, data } = req.body;

  // Valida assinatura (não-bloqueante; loga mas não descarta em dev).
  const signatureValid = verifyWebhookSignature(req);
  if (!signatureValid) {
    console.warn('[webhook] Assinatura inválida — ignorando evento.');
    return;
  }

  // Só processamos eventos de assinatura recorrente.
  if (type !== 'subscription_preapproval') return;

  const preapprovalId = data?.id;
  if (!preapprovalId) return;

  try {
    const preapproval = await getPreapproval(preapprovalId);

    // Tenta identificar o usuário por external_reference (fluxo legado)
    // ou pelo email do pagador (fluxo via init_point do plano).
    let userId = preapproval.external_reference || null;

    if (!userId) {
      const payerEmail = preapproval.payer_email
        ?? preapproval.payer?.email
        ?? null;

      if (!payerEmail) {
        console.warn('[webhook] Sem external_reference nem payer_email — ignorando.');
        return;
      }

      userId = await getUserByEmail(payerEmail);

      if (!userId) {
        console.warn(`[webhook] Email ${payerEmail} não encontrado no banco — ignorando.`);
        return;
      }
    }

    const appStatus = _mapMpStatus(preapproval.status);
    await updateUserSubscription(userId, {
      status: appStatus,
      preapprovalId: preapproval.id,
      nextBillingDate: preapproval.next_payment_date ?? null,
    });

    console.log(
      `[webhook] userId=${userId} | MP status=${preapproval.status} → app status=${appStatus}`
    );
  } catch (err) {
    console.error('[webhook] Erro ao processar evento:', err.message);
  }
});

// Mapeamento de status do Mercado Pago para os status internos do app.
function _mapMpStatus(mpStatus) {
  const map = {
    authorized: 'active',
    paused: 'past_due',
    cancelled: 'canceled',
    pending: 'trial',
  };
  return map[mpStatus] ?? 'expired';
}

module.exports = router;
