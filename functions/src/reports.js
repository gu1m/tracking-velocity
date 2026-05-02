/**
 * Fase 1 — Autenticidade do Relatório
 *
 * POST /reports/sign
 *   Recebe os hashes SHA-256 dos registros GPS do relatório,
 *   assina com RSA-SHA256 usando a chave privada do servidor,
 *   salva no Supabase e retorna o ID + URL de verificação.
 *
 * GET /reports/verify/:reportId
 *   Retorna os dados de verificação para um relatório assinado.
 *   Acessível publicamente (sem autenticação) para que terceiros
 *   (p.ex. tribunal de trânsito) possam verificar a autenticidade.
 */

const crypto = require('crypto');
const { Router } = require('express');
const { verifyFirebaseToken } = require('./auth');
const { storeReportSignature, getReportSignature } = require('./db');

const router = Router();

// ── Chave RSA ────────────────────────────────────────────────────────────────
// Configurada via variável de ambiente REPORT_PRIVATE_KEY no Railway.
// Formato: PEM completo com \n literais ou como variável multiline.
// Se não configurada, a assinatura é desabilitada em dev.
function getPrivateKey() {
  const key = process.env.REPORT_PRIVATE_KEY;
  if (!key) return null;
  // Railway armazena como string com \n literais → substituir por quebras reais.
  return key.replace(/\\n/g, '\n');
}

function getPublicKey() {
  const key = process.env.REPORT_PUBLIC_KEY;
  if (!key) return null;
  return key.replace(/\\n/g, '\n');
}

/**
 * Constrói a string canônica que será assinada:
 *   reportId|userId|generatedAt|recordCount|hash0,hash1,...hashN
 *
 * O hash da string canônica é o que o servidor assina — não o arquivo Excel.
 * Isso permite verificar a autenticidade sem precisar do arquivo original.
 */
function buildCanonical({ reportId, userId, generatedAt, recordCount, recordHashes }) {
  const hashesStr = recordHashes.join(',');
  return `${reportId}|${userId}|${generatedAt}|${recordCount}|${hashesStr}`;
}

/**
 * Assina a string canônica com RSA-SHA256.
 * Retorna a assinatura em base64.
 */
function signCanonical(canonical) {
  const privateKey = getPrivateKey();
  if (!privateKey) {
    // Dev: retorna uma assinatura fake para não travar o fluxo.
    return 'DEV_NO_KEY_' + crypto.createHash('sha256').update(canonical).digest('hex');
  }
  const sign = crypto.createSign('SHA256');
  sign.update(canonical, 'utf8');
  return sign.sign(privateKey, 'base64');
}

// ── POST /reports/sign ────────────────────────────────────────────────────────
router.post('/sign', verifyFirebaseToken, async (req, res) => {
  const { tripIds, recordHashes, recordCount } = req.body;

  if (!Array.isArray(recordHashes) || recordHashes.length === 0) {
    return res.status(400).json({ error: 'recordHashes deve ser um array não-vazio.' });
  }

  const reportId = crypto.randomUUID();
  const generatedAt = new Date().toISOString();
  const userId = req.user.uid;

  const canonical = buildCanonical({
    reportId,
    userId,
    generatedAt,
    recordCount: recordCount ?? recordHashes.length,
    recordHashes,
  });

  const signature = signCanonical(canonical);
  const verifyUrl = `${process.env.API_BASE_URL ?? 'https://tracking-velocity-production.up.railway.app'}/reports/verify/${reportId}`;

  try {
    await storeReportSignature({
      reportId,
      userId,
      tripIds: tripIds ?? [],
      recordCount: recordCount ?? recordHashes.length,
      recordHashes,
      canonical,
      signature,
      generatedAt,
    });
  } catch (err) {
    // Log mas não falha o request — o cliente ainda recebe a assinatura.
    console.error('[POST /reports/sign] Erro ao salvar no Supabase:', err.message);
  }

  return res.status(201).json({
    reportId,
    ntpTimestamp: generatedAt,
    signature,
    verifyUrl,
    canonical,
  });
});

// ── GET /reports/verify/:reportId ─────────────────────────────────────────────
// Rota pública — sem verifyFirebaseToken.
router.get('/verify/:reportId', async (req, res) => {
  const { reportId } = req.params;

  try {
    const data = await getReportSignature(reportId);

    if (!data) {
      return res.status(404).send(verifyHtml({
        reportId,
        valid: false,
        reason: 'Relatório não encontrado.',
      }));
    }

    // Verifica a assinatura com a chave pública.
    let signatureValid = false;
    const publicKey = getPublicKey();
    if (publicKey && !data.signature.startsWith('DEV_NO_KEY_')) {
      try {
        const verify = crypto.createVerify('SHA256');
        verify.update(data.canonical, 'utf8');
        signatureValid = verify.verify(publicKey, data.signature, 'base64');
      } catch (e) {
        signatureValid = false;
      }
    } else if (data.signature.startsWith('DEV_NO_KEY_')) {
      // Ambiente de dev — assinatura fake é considerada válida.
      signatureValid = true;
    }

    return res.status(200).send(verifyHtml({
      reportId,
      valid: signatureValid,
      generatedAt: data.generated_at,
      recordCount: data.record_count,
      tripIds: data.trip_ids,
    }));
  } catch (err) {
    console.error('[GET /reports/verify]', err.message);
    return res.status(500).send(verifyHtml({
      reportId,
      valid: false,
      reason: 'Erro interno ao verificar relatório.',
    }));
  }
});

// ── HTML de verificação ───────────────────────────────────────────────────────
function verifyHtml({ reportId, valid, generatedAt, recordCount, tripIds, reason }) {
  const statusColor = valid ? '#22c55e' : '#ef4444';
  const statusIcon = valid ? '✅' : '❌';
  const statusText = valid ? 'RELATÓRIO AUTÊNTICO' : 'RELATÓRIO INVÁLIDO OU NÃO ENCONTRADO';

  const detailRows = valid ? `
    <tr><td>ID do relatório</td><td><code>${reportId}</code></td></tr>
    <tr><td>Gerado em (NTP)</td><td>${new Date(generatedAt).toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })}</td></tr>
    <tr><td>Total de registros GPS</td><td>${recordCount}</td></tr>
    <tr><td>IDs das viagens</td><td>${(tripIds ?? []).join(', ')}</td></tr>
  ` : `<tr><td colspan="2">${reason ?? 'Assinatura inválida.'}</td></tr>`;

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Verificação de Relatório — Tracking Velocidade</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 600px; margin: 40px auto; padding: 16px; color: #1a1a2e; }
    h1 { font-size: 1.2rem; color: #555; }
    .status { font-size: 1.6rem; font-weight: 800; color: ${statusColor}; margin: 16px 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    td { padding: 10px 12px; border-bottom: 1px solid #eee; font-size: 0.9rem; }
    td:first-child { font-weight: 600; width: 45%; color: #555; }
    code { font-size: 0.75rem; word-break: break-all; background: #f5f5f5; padding: 2px 6px; border-radius: 4px; }
    footer { margin-top: 32px; font-size: 0.75rem; color: #aaa; text-align: center; }
  </style>
</head>
<body>
  <h1>Tracking Velocidade — Verificação de Relatório</h1>
  <div class="status">${statusIcon} ${statusText}</div>
  <table>${detailRows}</table>
  <footer>Esta verificação é emitida pelo servidor oficial Tracking Velocidade.<br>
  Gerada em ${new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })}</footer>
</body>
</html>`;
}

module.exports = router;
