const crypto = require('crypto');

// Valida o cabeçalho x-signature enviado pelo Mercado Pago.
//
// Formato do cabeçalho: "ts=<timestamp>,v1=<hash>"
// O hash é HMAC-SHA256 sobre a string:
//   "id:<data.id>;request-id:<x-request-id>;ts:<ts>;"
//
// Configure MP_WEBHOOK_SECRET no painel: Dashboard → Integrações → Webhooks.
// Em desenvolvimento (sem secret configurado) a validação é desabilitada.
function verifyWebhookSignature(req) {
  const secret = process.env.MP_WEBHOOK_SECRET;
  if (!secret) {
    // Em dev/staging sem secret, apenas loga e permite o evento.
    console.warn('[webhook] MP_WEBHOOK_SECRET não configurado — validação de assinatura desabilitada.');
    return true;
  }

  const signatureHeader = req.headers['x-signature'] ?? '';
  const requestId = req.headers['x-request-id'] ?? '';
  const dataId = req.body?.data?.id ?? '';

  // Extrai ts e v1 do cabeçalho.
  const parts = Object.fromEntries(
    signatureHeader.split(',').map((p) => p.split('='))
  );
  const { ts, v1: receivedHash } = parts;

  if (!ts || !receivedHash) return false;

  const payload = `id:${dataId};request-id:${requestId};ts:${ts};`;
  const expectedHash = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(receivedHash, 'hex'),
    Buffer.from(expectedHash, 'hex')
  );
}

module.exports = { verifyWebhookSignature };
