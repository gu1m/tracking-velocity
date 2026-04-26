/**
 * Script one-shot: cria o plano recorrente (preapproval_plan) no Mercado Pago.
 * Execute UMA vez — o ID gerado deve ser copiado para MP_PLAN_ID no .env.
 *
 * Uso:
 *   cd functions
 *   node scripts/create_mp_plan.js
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const { MercadoPagoConfig, PreApprovalPlan } = require('mercadopago');

async function main() {
  const accessToken = process.env.MP_ACCESS_TOKEN;
  if (!accessToken || accessToken.includes('xxxxxxx')) {
    console.error('❌  Preencha MP_ACCESS_TOKEN no arquivo functions/.env antes de continuar.');
    process.exit(1);
  }

  const client = new MercadoPagoConfig({ accessToken });
  const planApi = new PreApprovalPlan(client);

  console.log('Criando plano recorrente no Mercado Pago…');

  const response = await planApi.create({
    body: {
      reason: 'Tracking Velocidade Premium — mensal',
      auto_recurring: {
        frequency: 1,
        frequency_type: 'months',
        transaction_amount: 13.99,
        currency_id: 'BRL',
        billing_day: 10,          // dia do mês para cobrar
        billing_day_proportional: true,
      },
      payment_methods_allowed: {
        payment_types: [{ id: 'credit_card' }, { id: 'debit_card' }],
      },
      back_url: process.env.MP_BACK_URL || 'https://seuapp.com/subscription/callback',
    },
  });

  if (!response.id) {
    console.error('❌  Resposta inesperada do MP:', JSON.stringify(response, null, 2));
    process.exit(1);
  }

  console.log('\n✅  Plano criado com sucesso!');
  console.log(`   ID do plano: ${response.id}`);
  console.log(`   Status:      ${response.status}`);
  console.log('\n👉  Adicione ao functions/.env:');
  console.log(`   MP_PLAN_ID=${response.id}`);
}

main().catch((err) => {
  console.error('Erro:', err.message);
  process.exit(1);
});
