const { MercadoPagoConfig, PreApproval } = require('mercadopago');

// Reutiliza a mesma instância durante o ciclo de vida do processo.
const client = new MercadoPagoConfig({
  accessToken: process.env.MP_ACCESS_TOKEN,
});

const preApprovalApi = new PreApproval(client);

// ── Criar assinatura recorrente ──────────────────────────────────────────────
// Cria uma preapproval vinculada ao plano já existente (MP_PLAN_ID).
// O campo external_reference é o UID do Firebase — usado pelo webhook para
// identificar qual usuário atualizar.
async function createSubscription(userId) {
  if (!process.env.MP_ACCESS_TOKEN) {
    throw new Error('MP_ACCESS_TOKEN não configurado no servidor.');
  }
  if (!process.env.MP_PLAN_ID) {
    throw new Error('MP_PLAN_ID não configurado no servidor. Execute scripts/create_mp_plan.js primeiro.');
  }

  // Nota: ao usar preapproval_plan_id, NÃO incluir auto_recurring —
  // essas configs já estão definidas no plano.
  const response = await preApprovalApi.create({
    body: {
      preapproval_plan_id: process.env.MP_PLAN_ID,
      reason: 'Tracking Velocidade Premium — mensal',
      external_reference: userId,
      back_url: process.env.MP_BACK_URL || 'https://trackingvelocidade.com.br/callback',
    },
  });

  if (!response.init_point) {
    throw new Error(`MP não retornou init_point. Resposta: ${JSON.stringify(response)}`);
  }

  return {
    initPoint: response.init_point,
    preapprovalId: response.id,
  };
}

// ── Cancelar assinatura ──────────────────────────────────────────────────────
async function cancelSubscription(preapprovalId) {
  await preApprovalApi.update({
    id: preapprovalId,
    body: { status: 'cancelled' },
  });
}

module.exports = { createSubscription, cancelSubscription };
