import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';

process.env.DB_DRIVER = 'pglite';
process.env.OTP_FIXED = '123456';
process.env.RATE_LIMIT_DISABLED = 'true';
process.env.PAYMENT_POLL_MS = '5';
process.env.UPLOAD_DIR = path.join(os.tmpdir(), `ws-uploads-${process.pid}`);
process.env.ADMIN_PHONES = '0197000009';

const { initDb, closeDb } = await import('../src/db.js');
const { createApp } = await import('../src/app.js');

let server, base;
before(async () => {
  await initDb();
  server = createApp().listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});
after(async () => {
  server.close();
  await closeDb();
});

async function api(method, p, body, token) {
  const res = await fetch(base + p, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json };
}

async function login(phone, name) {
  assert.equal((await api('POST', '/auth/request-code', { phone })).status, 200);
  const r = await api('POST', '/auth/verify', { phone, code: '123456', name });
  assert.equal(r.status, 200);
  return r.json.token;
}
let n = 0;
const op = (type, payload) => ({ id: `op${++n}`, type, payload, date: new Date().toISOString() });
const push = (t, type, payload) => api('POST', '/sync/ops', op(type, payload), t);

test('parcours complet : boutique, commande, livraison, avis, retrait, remboursement', async () => {
  const seller = await login('0197000001', 'Vendeur');
  const buyer = await login('0197000002', 'Client');

  // mauvais code
  await api('POST', '/auth/request-code', { phone: '0197000003' });
  assert.equal((await api('POST', '/auth/verify', { phone: '0197000003', code: '000000' })).status, 400);

  // boutique + produit
  assert.equal((await push(seller, 'store.create', { entity: { id: 'ch1', name: 'Boutique Test', category: 'Sacs', color: 4278225275, delivers: true, deliveryFee: 1000, phone: '0197000001' } })).status, 200);
  assert.equal((await push(seller, 'post.create', { channelId: 'ch1', postId: 'p1', entity: { id: 'p1', type: 1, time: '10:00', title: 'Sac', text: 'Beau sac', price: 1000, stock: 3, variants: ['S', 'M'], category: 'Sacs' } })).status, 200);

  // un autre utilisateur ne peut pas publier dans cette boutique
  assert.equal((await push(buyer, 'post.create', { channelId: 'ch1', postId: 'p2', entity: { id: 'p2', type: 0, text: 'pirate' } })).status, 403);

  // abonnement
  assert.equal((await push(buyer, 'store.follow', { channelId: 'ch1', followed: true })).status, 200);

  // commande sans paiement refusée
  const order = { ref: 'WS100', delivery: false, lines: [{ c: 'ch1', p: 'p1', q: 2, v: 'S' }] };
  assert.equal((await push(buyer, 'order.create', { entity: order })).status, 402);

  // option obligatoire
  assert.equal((await api('POST', '/payments', { provider: 'MTN MoMo', phone: '0197000002', amount: 2000, reference: 'WS100' }, buyer)).json.ok, true);
  assert.equal((await push(buyer, 'order.create', { entity: { ...order, lines: [{ c: 'ch1', p: 'p1', q: 2 }] } })).status, 400);

  // commande valide + idempotence
  const o = op('order.create', { entity: order });
  assert.equal((await api('POST', '/sync/ops', o, buyer)).status, 200);
  assert.equal((await api('POST', '/sync/ops', o, buyer)).status, 200);
  let snap = (await api('GET', '/sync/snapshot', null, buyer)).json;
  assert.equal(snap.channels[0].posts[0].stock, 1);
  assert.equal(snap.orders.length, 1);
  assert.equal(snap.channels[0].followed, true);
  assert.equal(snap.channels[0].mine, false);

  // stock insuffisant
  await api('POST', '/payments', { provider: 'MTN MoMo', phone: '0197000002', amount: 2000, reference: 'WS101' }, buyer);
  assert.equal((await push(buyer, 'order.create', { entity: { ref: 'WS101', lines: [{ c: 'ch1', p: 'p1', q: 2, v: 'M' }] } })).status, 409);

  // statuts : seulement le vendeur, dans l'ordre
  assert.equal((await push(buyer, 'order.status', { ref: 'WS100', status: 1 })).status, 403);
  assert.equal((await push(seller, 'order.status', { ref: 'WS100', status: 3 })).status, 409);
  for (const s of [1, 2, 3]) assert.equal((await push(seller, 'order.status', { ref: 'WS100', status: s })).status, 200);

  // avis (une seule fois)
  assert.equal((await push(buyer, 'review.create', { entity: { id: 'r1', postId: 'p1', rating: 5, text: 'Top' } })).status, 200);
  assert.equal((await push(buyer, 'review.create', { entity: { id: 'r2', postId: 'p1', rating: 4 } })).status, 403);

  // retrait : solde = 2000 - 5 % = 1900
  assert.equal((await push(seller, 'payout.request', { entity: { id: 'po1', channelId: 'ch1', amount: 5000, phone: '0197000001' } })).status, 400);
  assert.equal((await push(seller, 'payout.request', { entity: { id: 'po2', channelId: 'ch1', amount: 1900, phone: '0197000001' } })).status, 200);
  assert.equal((await push(seller, 'payout.request', { entity: { id: 'po3', channelId: 'ch1', amount: 1000, phone: '0197000001' } })).status, 400);

  // livraison : frais calculés par le serveur, annulation = remboursement + stock restitué
  await push(seller, 'post.update', { postId: 'p1', entity: { id: 'p1', type: 1, title: 'Sac', text: 'Beau sac', price: 1000, stock: 5, variants: ['S', 'M'], category: 'Sacs' } });
  await api('POST', '/payments', { provider: 'Moov Money', phone: '0197000002', amount: 2000, reference: 'WS102' }, buyer);
  assert.equal((await push(buyer, 'order.create', { entity: { ref: 'WS102', delivery: true, address: 'Cotonou', lines: [{ c: 'ch1', p: 'p1', q: 1, v: 'M' }] } })).status, 200);
  assert.equal((await push(buyer, 'order.status', { ref: 'WS102', status: 4 })).status, 200);
  snap = (await api('GET', '/sync/snapshot', null, buyer)).json;
  const o2 = snap.orders.find((x) => x.ref === 'WS102');
  assert.equal(o2.status, 4);
  assert.equal(o2.refunded, true);
  assert.equal(snap.channels[0].posts[0].stock, 5);

  // vue vendeur
  const sSnap = (await api('GET', '/sync/snapshot', null, seller)).json;
  assert.equal(sSnap.channels[0].mine, true);
  assert.ok(sSnap.orders.length >= 2);
  assert.equal(sSnap.reports, undefined);
});

test('vérification de boutique réservée aux admins, signalements', async () => {
  const admin = await login('0197000009', 'Admin');
  const user = await login('0197000004', 'Autre');
  assert.equal((await push(user, 'store.verify', { channelId: 'ch1', verified: true })).status, 403);
  assert.equal((await push(user, 'report.create', { channelId: 'ch1', reason: 'Arnaque' })).status, 200);
  assert.equal((await push(admin, 'store.verify', { channelId: 'ch1', verified: true })).status, 200);
  const snap = (await api('GET', '/sync/snapshot', null, admin)).json;
  assert.equal(snap.channels.find((c) => c.id === 'ch1').verified, true);
  assert.equal(snap.reports.length, 1);
  assert.equal((await api('GET', '/channels/ch1')).json.name, 'Boutique Test');
  assert.equal((await api('GET', '/sync/snapshot')).status, 401);
});

test('changement de numéro et suppression du compte', async () => {
  const t = await login('0197000005', 'Zoe');
  await api('POST', '/auth/request-code', { phone: '0197000006' });
  assert.equal((await api('POST', '/me/phone', { phone: '0197000006', code: '123456' }, t)).status, 200);
  assert.equal((await api('GET', '/me', null, t)).json.user.phone, '0197000006');
  assert.equal((await api('DELETE', '/me', null, t)).status, 200);
  assert.equal((await api('GET', '/me', null, t)).status, 401);
});

test('upload de média et pages de partage', async () => {
  const t = await login('0197000007', 'Max');
  const fd = new FormData();
  fd.append('kind', 'post');
  fd.append('file', new Blob([new Uint8Array([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' }), 'a.jpg');
  const r = await fetch(`${base}/media`, { method: 'POST', headers: { Authorization: `Bearer ${t}` }, body: fd });
  assert.equal(r.status, 200);
  const { url } = await r.json();
  assert.match(url, /\/uploads\/.+\.jpg$/);
  assert.equal((await fetch(url.replace(/^https?:\/\/[^/]+/, base))).status, 200);
  const bad = new FormData();
  bad.append('file', new Blob(['x'], { type: 'text/html' }), 'a.html');
  assert.equal((await fetch(`${base}/media`, { method: 'POST', headers: { Authorization: `Bearer ${t}` }, body: bad })).status, 400);
  const html = await (await fetch(`${base}/s/ch1`)).text();
  assert.match(html, /Boutique Test/);
});
