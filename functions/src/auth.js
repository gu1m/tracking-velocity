const { verifyIdToken } = require('./firebase');

// Middleware Express: valida o Firebase ID Token enviado pelo app Flutter.
// Uso: router.post('/rota', verifyFirebaseToken, handler)
async function verifyFirebaseToken(req, res, next) {
  const authHeader = req.headers.authorization ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Token de autenticação ausente.' });
  }

  try {
    req.user = await verifyIdToken(token);
    next();
  } catch {
    res.status(401).json({ error: 'Token inválido ou expirado.' });
  }
}

module.exports = { verifyFirebaseToken };
