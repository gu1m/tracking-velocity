/**
 * Firebase Admin SDK — apenas autenticação.
 * Dados de usuário/assinatura/viagens vivem no Supabase (db.js).
 */

const admin = require('firebase-admin');

// Inicializa uma única vez (seguro em hot-reload e Cloud Functions).
if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

// Verifica um Firebase ID Token e retorna o DecodedIdToken.
async function verifyIdToken(idToken) {
  return admin.auth().verifyIdToken(idToken);
}

// Exclui um usuário do Firebase Auth (usado em DELETE /users/me).
async function deleteFirebaseUser(uid) {
  return admin.auth().deleteUser(uid);
}

module.exports = { verifyIdToken, deleteFirebaseUser, admin };
