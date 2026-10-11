import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import multer from 'multer';
import { deleteAccount } from './account.js';
import { checkCode, publicUser, requestCode, requireAuth, verify } from './auth.js';
import { config } from './config.js';
import { db } from './db.js';
import { applyOp } from './ops.js';
import { chargePayment, refundByReference } from './payments.js';
import { buildChannels, buildSnapshot } from './snapshot.js';
import { HttpError, normalizePhone } from './util.js';

const asyncH = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const limiter = (limit) =>
  process.env.RATE_LIMIT_DISABLED === 'true' ? (req, res, next) => next() : rateLimit({ windowMs: 60_000, limit, standardHeaders: true, legacyHeaders: false });
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const MEDIA_TYPES = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp', 'image/gif': '.gif', 'video/mp4': '.mp4', 'video/quicktime': '.mov', 'video/webm': '.webm' };

export function createApp() {
  const app = express();
  app.set('trust proxy', 1);
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors());
  app.use(express.json({ limit: '1mb', verify: (req, res, buf) => { req.rawBody = buf; } }));
  app.use(limiter(600));

  fs.mkdirSync(config.uploadDir, { recursive: true });
  const upload = multer({
    storage: multer.diskStorage({
      destination: config.uploadDir,
      filename: (req, file, cb) => cb(null, `${crypto.randomUUID()}${MEDIA_TYPES[file.mimetype] || ''}`),
    }),
    limits: { fileSize: 60 * 1024 * 1024, files: 1 },
    fileFilter: (req, file, cb) => cb(MEDIA_TYPES[file.mimetype] ? null : new HttpError(400, 'Type de fichier non autorisé'), !!MEDIA_TYPES[file.mimetype]),
  });
  app.use('/uploads', express.static(path.resolve(config.uploadDir), { maxAge: '7d', setHeaders: (res) => res.setHeader('X-Content-Type-Options', 'nosniff') }));

  app.get('/health', (req, res) => res.json({ ok: true }));

  // ---- Authentification
  app.post('/auth/request-code', limiter(20), asyncH(async (req, res) => {
    await requestCode(req.body?.phone);
    res.json({ ok: true });
  }));
  app.post('/auth/verify', limiter(20), asyncH(async (req, res) => {
    const { phone, code, name } = req.body || {};
    res.json(await verify(phone, code, name));
  }));
  app.get('/me', requireAuth, asyncH(async (req, res) => {
    const u = (await db.query('SELECT * FROM users WHERE id=$1', [req.user.id])).rows[0];
    res.json({ user: publicUser(u) });
  }));
  app.post('/me/phone', requireAuth, limiter(20), asyncH(async (req, res) => {
    const phone = normalizePhone(req.body?.phone);
    if (phone.length < 8) throw new HttpError(400, 'Numéro invalide');
    await checkCode(phone, req.body?.code);
    const other = (await db.query('SELECT id FROM users WHERE phone=$1', [phone])).rows[0];
    if (other && other.id !== req.user.id) throw new HttpError(409, 'Ce numéro est déjà utilisé');
    await db.query('UPDATE users SET phone=$2, phone_display=$3 WHERE id=$1', [req.user.id, phone, String(req.body.phone).trim()]);
    const u = (await db.query('SELECT * FROM users WHERE id=$1', [req.user.id])).rows[0];
    res.json({ user: publicUser(u) });
  }));
  app.delete('/me', requireAuth, asyncH(async (req, res) => {
    await deleteAccount(req.user.id);
    res.json({ ok: true });
  }));

  // ---- Médias
  app.post('/media', requireAuth, limiter(60), upload.single('file'), (req, res) => {
    if (!req.file) throw new HttpError(400, 'Fichier manquant');
    res.json({ url: `${config.publicUrl}/uploads/${req.file.filename}` });
  });

  // ---- Paiements
  app.post('/payments', requireAuth, limiter(30), asyncH(async (req, res) => {
    const b = req.body || {};
    res.json(await chargePayment(db, req.user.id, { provider: b.provider, phone: b.phone, amount: Number(b.amount), reference: b.reference }));
  }));
  app.post('/payments/refund', requireAuth, limiter(30), asyncH(async (req, res) => {
    const ref = String(req.body?.reference || '');
    const p = (await db.query('SELECT * FROM payments WHERE reference=$1', [ref])).rows[0];
    if (!p) throw new HttpError(404, 'Paiement introuvable');
    const order = (await db.query('SELECT * FROM orders WHERE ref=$1', [ref])).rows[0];
    const seller = order
      ? (await db.query('SELECT 1 FROM order_lines l JOIN channels c ON c.id=l.channel_id WHERE l.order_ref=$1 AND c.owner_id=$2 LIMIT 1', [ref, req.user.id])).rows.length > 0
      : false;
    if (order && order.status === 3) throw new HttpError(409, 'Commande déjà livrée');
    if (p.user_id !== req.user.id && !seller) throw new HttpError(403, 'Remboursement non autorisé');
    const r = await refundByReference(db, ref);
    res.json({ ok: !!r.ok, message: r.message });
  }));
  // Confirmation asynchrone envoyée par le prestataire (signature HMAC-SHA256 du corps brut dans x-signature).
  app.post('/webhooks/payments', asyncH(async (req, res) => {
    if (!config.webhookSecret) throw new HttpError(501, 'Webhook non configuré');
    const sig = crypto.createHmac('sha256', config.webhookSecret).update(req.rawBody || '').digest('hex');
    const got = String(req.headers['x-signature'] || '');
    if (got.length !== sig.length || !crypto.timingSafeEqual(Buffer.from(got), Buffer.from(sig))) throw new HttpError(401, 'Signature invalide');
    const { reference, status } = req.body || {};
    if (!['succeeded', 'failed'].includes(status)) throw new HttpError(400, 'Statut invalide');
    await db.query("UPDATE payments SET status=$2 WHERE reference=$1 AND status='pending'", [String(reference), status]);
    res.json({ ok: true });
  }));

  // ---- Synchronisation
  app.post('/sync/ops', requireAuth, limiter(300), asyncH(async (req, res) => {
    await applyOp(req.user, req.body);
    res.json({ ok: true });
  }));
  app.get('/sync/snapshot', requireAuth, asyncH(async (req, res) => res.json(await buildSnapshot(req.user))));

  // ---- Lecture publique (liens profonds)
  const soft = (req, res, next) => requireAuth(req, res, () => next());
  app.get('/channels/:id', soft, asyncH(async (req, res) => {
    const [c] = await buildChannels(req.user || null, req.params.id);
    if (!c) throw new HttpError(404, 'Boutique introuvable');
    res.json(c);
  }));
  app.get('/posts/:id', soft, asyncH(async (req, res) => {
    const row = (await db.query('SELECT channel_id FROM posts WHERE id=$1', [req.params.id])).rows[0];
    if (!row) throw new HttpError(404, 'Publication introuvable');
    const [c] = await buildChannels(req.user || null, row.channel_id);
    res.json({ channelId: c.id, post: c.posts.find((p) => p.id === req.params.id) });
  }));

  // ---- Pages de partage (aperçu des liens whatstore.store/s/... et /p/...) + fichiers .well-known
  const page = (title, desc, image) => `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title><meta property="og:title" content="${esc(title)}"><meta property="og:description" content="${esc(desc)}">${image ? `<meta property="og:image" content="${esc(image)}">` : ''}
<style>body{font-family:system-ui,sans-serif;max-width:480px;margin:10vh auto;padding:0 20px;text-align:center}h1{font-size:24px}p{color:#555}</style></head>
<body><h1>${esc(title)}</h1><p>${esc(desc)}</p><p>Ouvre ce lien dans l'application <b>Whatstore</b> pour voir la boutique et commander.</p></body></html>`;
  app.get('/s/:id', asyncH(async (req, res) => {
    const c = (await db.query('SELECT name, description, logo_url FROM channels WHERE id=$1', [req.params.id])).rows[0];
    if (!c) return res.status(404).send(page('Boutique introuvable', 'Ce lien n\'est plus valide.'));
    res.send(page(c.name, c.description || 'Boutique sur Whatstore', c.logo_url));
  }));
  app.get('/p/:id', asyncH(async (req, res) => {
    const p = (await db.query('SELECT title, text, price, image_url FROM posts WHERE id=$1', [req.params.id])).rows[0];
    if (!p) return res.status(404).send(page('Produit introuvable', 'Ce lien n\'est plus valide.'));
    res.send(page(p.title || 'Publication', `${p.price ? `${p.price} FCFA · ` : ''}${(p.text || '').slice(0, 140)}`, p.image_url));
  }));
  app.get('/.well-known/assetlinks.json', (req, res) =>
    res.json([{ relation: ['delegate_permission/common.handle_all_urls'], target: { namespace: 'android_app', package_name: config.androidPackage, sha256_cert_fingerprints: config.androidSha256 ? [config.androidSha256] : [] } }]));
  app.get('/.well-known/apple-app-site-association', (req, res) =>
    res.json({ applinks: { apps: [], details: config.appleAppId ? [{ appID: config.appleAppId, paths: ['/s/*', '/p/*'] }] : [] } }));

  app.use((req, res) => res.status(404).json({ message: 'Route introuvable' }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err instanceof HttpError) return res.status(err.status).json({ message: err.message });
    if (err instanceof multer.MulterError) return res.status(400).json({ message: err.message });
    if (err.type === 'entity.parse.failed') return res.status(400).json({ message: 'JSON invalide' });
    console.error(err);
    res.status(500).json({ message: 'Erreur serveur' });
  });
  return app;
}
