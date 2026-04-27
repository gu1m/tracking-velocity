const MP_API = 'https://api.mercadopago.com';

function authHeaders() {
  return {
    Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
    'Content-Type': 'application/json',
  };
}

// ── Checkout via plano ───────────────────────────────────────────────────────
// Busca o init_point do plano existente.
// O POST /preapproval exige card_token_id (fluxo de cobrança direta).
// Para assinatura via checkout do MP, usamos o init_point do próprio plano.
async function createSubscription(_userId) {
  if (!process.env.MP_ACCESS_TOKEN) {
    throw new Error('MP_ACCESS_TOKEN não configurado no servidor.');
  }
  if (!process.env.MP_PLAN_ID) {
    throw new Error('MP_PLAN_ID não configurado. Execute scripts/create_mp_plan.js primeiro.');
  }

  const res = await fetch(`${MP_API}/preapproval_plan/${process.env.MP_PLAN_ID}`, {
    headers: authHeaders(),
  });

  const plan = await res.json();

  if (!res.ok) {
    throw new Error(`MP plano ${res.status}: ${plan.message || JSON.stringify(plan)}`);
  }

  // O plano retorna init_point — URL do checkout onde o usuário assina.
  const initPoint = plan.init_point;
  if (!initPoint) {
    throw new Error(`Plano sem init_point. Status do plano: ${plan.status}. Verifique se o plano está ativo no painel do MP.`);
  }

  return { initPoint, preapprovalId: null };
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

// ── Buscar preapproval ───────────────────────────────────────────────────────
async function getPreapproval(preapprovalId) {
  const res = await fetch(`${MP_API}/preapproval/${preapprovalId}`, {
    headers: authHeaders(),
  });
  if (!res.ok) throw new Error(`MP getPreapproval ${res.status}`);
  return res.json();
}

module.exports = { createSubscription, cancelSubscription, getPreapproval };
