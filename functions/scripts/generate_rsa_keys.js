/**
 * Gera o par de chaves RSA-2048 para assinar/verificar relatórios.
 *
 * Execute UMA VEZ e salve as chaves como variáveis de ambiente no Railway:
 *   REPORT_PRIVATE_KEY  — chave privada (nunca exponha)
 *   REPORT_PUBLIC_KEY   — chave pública (pode ser pública)
 *
 * Uso:
 *   node scripts/generate_rsa_keys.js
 */

const crypto = require('crypto');

const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding:  { type: 'spki',  format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});

console.log('\n=== CHAVE PRIVADA (REPORT_PRIVATE_KEY) ===');
console.log('Cole no Railway exatamente como está abaixo (incluindo BEGIN/END):');
console.log(privateKey);

console.log('\n=== CHAVE PÚBLICA (REPORT_PUBLIC_KEY) ===');
console.log('Cole no Railway exatamente como está abaixo:');
console.log(publicKey);

console.log('\n✅ Chaves geradas! Configure no Railway:');
console.log('   Railway Dashboard → seu projeto → Variables → Add Variable');
console.log('   REPORT_PRIVATE_KEY = <chave privada acima>');
console.log('   REPORT_PUBLIC_KEY  = <chave pública acima>');
