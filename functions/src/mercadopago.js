const MP_API = 'https://api.mercadopago.com';

function authHeaders() {
  return {
    Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
    'Content-Type': 'application/json',
  };
}

// ── Criar assinatura recorrente ──────────────────────────────────────────────
// Cria uma preapproval vinculada ao plano (MP_PLAN_ID) via REST direto.
// O SDK do MP adiciona campos extras que causam "card_token_id is required".
async function createSubscription(userId) {
  if (!process.env.MP_ACCESS_TOKEN) {
    throw new Error('MP_ACCESS_TOKEN não configurado no servidor.');
  }
  if (!process.env.MP_PLAN_ID) {
    throw new Error('MP_PLAN_ID não configurado. Execute scripts/create_mp_plan.js primeiro.');
  }

  const body = {
    preapproval_plan_id: process.env.MP_PLAN_ID,
    reason: 'Tracking Velocidade Premium — mensal',
    external_reference: userId,
    back_url: process.env.MP_BACK_URL || 'https://trackingvelocidade.com.br/callback',
  };

  const res = await fetch(`${MP_API}/preapproval`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(body),
  });

  const data = await res.json();

  if (!res.ok) {
    const detail = data.message || data.error || JSON.stringify(data);
    throw new Error(`MP ${res.status}: ${detail}`);
  }

  if (!data.init_point) {
    throw new Error(`MP não retornou init_point. Resposta: ${JSON.stringify(data)}`);
  }

  return {
    initPoint: data.init_point,
    preapprovalId: data.id,
  };
}

// ── Cancelar assinatura ──────────────────────────────────────────────────────
async function cancelSubscription(preapprovalId) {
  const res = await fetch(`${MP_API}/preapproval/${preapprovalId}`, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify({ status: 'cancelled' }),
  });

  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(`MP cancelar ${res.status}: ${data.message || JSON.stringify(data)}`);
  }
}

module.exports = { createSubscription, cancelSubscription };
