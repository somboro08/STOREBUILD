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

test('catalogue physique : étiquettes, produits, stock unifié magasin / en ligne', async () => {
  const seller = await login('0197000011', 'Vendeuse');
  const buyer = await login('0197000012', 'Cliente');
  const stranger = await login('0197000013', 'Autre');

  assert.equal((await push(seller, 'store.create', { entity: { id: 'ch2', name: 'Papeterie Test', category: 'Fournitures scolaires', phone: '0197000011' } })).status, 200);

  // sous-catalogues
  assert.equal((await push(seller, 'catalog.group.save', { entity: { id: 'g1', channelId: 'ch2', name: 'Cahiers' } })).status, 200);
  assert.equal((await push(seller, 'catalog.group.save', { entity: { id: 'g2', channelId: 'ch2', parentId: 'g1', name: '100 pages' } })).status, 200);
  assert.equal((await push(stranger, 'catalog.group.save', { entity: { id: 'g3', channelId: 'ch2', name: 'Pirate' } })).status, 403);

  // étiquettes vierges
  assert.equal((await push(seller, 'catalog.codes.create', { channelId: 'ch2', codes: ['AAAAAA', 'BBBBBB'] })).status, 200);
  assert.equal((await push(seller, 'catalog.codes.create', { channelId: 'ch2', codes: ['x'] })).status, 400);

  // produit rattaché à l'étiquette AAAAAA
  const item = { id: 'it1', channelId: 'ch2', code: 'AAAAAA', name: 'Cahier 100 pages', groupId: 'g2', price: 500, cost: 300, lowStock: 2, barcodes: ['6001'], details: [['Pages', '100']], description: 'Cahier spiralé', usage: 'Prendre des notes', location: 'Rayon B' };
  assert.equal((await push(seller, 'catalog.item.save', { entity: item })).status, 200);
  assert.equal((await push(seller, 'catalog.item.save', { entity: { ...item, id: 'it2', name: 'Doublon' } })).status, 409); // même code
  assert.equal((await push(seller, 'catalog.item.save', { entity: { ...item, id: 'it3', code: 'CCCCCC', barcodes: ['6001'] } })).status, 409); // même code-barres
  assert.equal((await push(stranger, 'catalog.item.save', { entity: { ...item, id: 'it4', code: 'DDDDDD', barcodes: [] } })).status, 403);

  // stock par mouvements ; le stock envoyé dans la fiche est ignoré
  assert.equal((await push(seller, 'stock.move', { id: 'm1', itemId: 'it1', channelId: 'ch2', delta: 10, kind: 'initial' })).status, 200);
  assert.equal((await push(seller, 'catalog.item.save', { entity: { ...item, stock: 999 } })).status, 200);
  assert.equal((await push(buyer, 'stock.move', { id: 'm2', itemId: 'it1', delta: -1, kind: 'vente' })).status, 403);
  assert.equal((await push(seller, 'stock.move', { id: 'm3', itemId: 'it1', delta: 1, kind: 'inconnu' })).status, 400);

  // publication en ligne liée : même stock
  assert.equal((await push(seller, 'post.create', { channelId: 'ch2', postId: 'p9', entity: { id: 'p9', type: 1, time: '09:00', title: 'Cahier 100 pages', text: 'Cahier', price: 500, stock: 10, category: 'Fournitures scolaires' } })).status, 200);
  assert.equal((await push(seller, 'catalog.item.save', { entity: { ...item, postId: 'p9' } })).status, 200);

  // vente en ligne -> le catalogue baisse aussi
  assert.equal((await api('POST', '/payments', { provider: 'MTN MoMo', phone: '0197000012', amount: 1500, reference: 'WS300' }, buyer)).json.ok, true);
  assert.equal((await push(buyer, 'order.create', { entity: { ref: 'WS300', lines: [{ c: 'ch2', p: 'p9', q: 3 }] } })).status, 200);
  let sSnap = (await api('GET', '/sync/snapshot', null, seller)).json;
  assert.equal(sSnap.items.find((i) => i.id === 'it1').stock, 7);
  assert.equal(sSnap.channels.find((c) => c.id === 'ch2').posts[0].stock, 7);
  assert.ok(sSnap.movements.some((m) => m.kind === 'vente_en_ligne' && m.delta === -3));

  // vente en magasin -> la publication en ligne baisse aussi
  assert.equal((await push(seller, 'stock.move', { id: 'm4', itemId: 'it1', channelId: 'ch2', delta: -5, kind: 'vente' })).status, 200);
  sSnap = (await api('GET', '/sync/snapshot', null, seller)).json;
  assert.equal(sSnap.items.find((i) => i.id === 'it1').stock, 2);
  assert.equal(sSnap.channels.find((c) => c.id === 'ch2').posts[0].stock, 2);

  // annulation de la commande en ligne : stock restitué partout
  assert.equal((await push(buyer, 'order.status', { ref: 'WS300', status: 4 })).status, 200);
  sSnap = (await api('GET', '/sync/snapshot', null, seller)).json;
  assert.equal(sSnap.items.find((i) => i.id === 'it1').stock, 5);
  assert.equal(sSnap.channels.find((c) => c.id === 'ch2').posts[0].stock, 5);

  // consultation publique : pas de prix d'achat, stock arrondi ; propriétaire : tout
  await push(seller, 'stock.move', { id: 'm5', itemId: 'it1', delta: 20, kind: 'entree' }); // stock = 25
  const pub = (await api('GET', '/catalog/ch2/aaaaaa')).json.item;
  assert.equal(pub.cost, 0);
  assert.equal(pub.stock, 3); // lowStock + 1 : "disponible" sans révéler la quantité
  assert.equal(pub.usage, 'Prendre des notes');
  const own = (await api('GET', '/catalog/ch2/AAAAAA', null, seller)).json.item;
  assert.equal(own.cost, 300);
  assert.equal(own.stock, 25);
  assert.equal((await api('GET', '/catalog/ch2/6001')).json.item.id, 'it1'); // par code-barres
  assert.equal((await api('GET', '/catalog/ch2/BBBBBB')).json.blank, true); // étiquette vierge
  assert.equal((await api('GET', '/catalog/ch2/ZZZZZZ')).status, 404);
  assert.match(await (await fetch(`${base}/q/ch2/AAAAAA`)).text(), /Cahier 100 pages/);

  // snapshot : abonné voit le catalogue sans les données sensibles, vendeur voit étiquettes vierges et mouvements
  assert.equal((await api('GET', '/sync/snapshot', null, buyer)).json.items.length, 0);
  await push(buyer, 'store.follow', { channelId: 'ch2', followed: true });
  const bSnap = (await api('GET', '/sync/snapshot', null, buyer)).json;
  assert.equal(bSnap.items[0].cost, 0);
  assert.equal(bSnap.items[0].stock, 3);
  assert.deepEqual(bSnap.movements, []);
  assert.deepEqual(bSnap.blankCodes, []);
  sSnap = (await api('GET', '/sync/snapshot', null, seller)).json;
  assert.deepEqual(sSnap.blankCodes.map((b) => b.code), ['BBBBBB']);
  assert.equal(sSnap.groups.length, 2);

  // suppression d'un sous-catalogue : les produits remontent
  assert.equal((await push(seller, 'catalog.group.delete', { id: 'g2', channelId: 'ch2' })).status, 200);
  sSnap = (await api('GET', '/sync/snapshot', null, seller)).json;
  assert.equal(sSnap.items.find((i) => i.id === 'it1').groupId, 'g1');
});

test('équipe et rôles, caisse, achats, réservations, alertes, demande, registre', async () => {
  const { db } = await import('../src/db.js');
  const owner = await login('0197000021', 'Patronne');
  const cashier = await login('0197000022', 'Caissier');
  const keeper = await login('0197000023', 'Magasinier');
  const client = await login('0197000024', 'Cliente');

  await push(owner, 'store.create', { entity: { id: 'ch3', name: 'Grand Magasin', category: 'Mode', phone: '0197000021' } });
  await push(owner, 'catalog.item.save', { entity: { id: 'x1', channelId: 'ch3', code: 'XXXX11', name: 'Sac', price: 2000, cost: 1000, lowStock: 2, barcodes: ['7001'], usage: 'Porter des affaires' } });
  await push(owner, 'catalog.item.save', { entity: { id: 'x2', channelId: 'ch3', code: 'XXXX22', name: 'Stylo', price: 100, cost: 40, lowStock: 5 } });
  await push(owner, 'stock.move', { id: 'a1', itemId: 'x1', delta: 10, kind: 'initial' });
  await push(owner, 'stock.move', { id: 'a2', itemId: 'x2', delta: 100, kind: 'initial' });

  // équipe : seul le propriétaire invite
  assert.equal((await push(cashier, 'team.invite', { channelId: 'ch3', phone: '0197000022', role: 'manager' })).status, 403);
  assert.equal((await push(owner, 'team.invite', { channelId: 'ch3', phone: '0197000022', name: 'Caissier', role: 'cashier' })).status, 200);
  assert.equal((await push(owner, 'team.invite', { channelId: 'ch3', phone: '0197000023', name: 'Magasinier', role: 'stock' })).status, 200);
  assert.equal((await push(owner, 'team.invite', { channelId: 'ch3', phone: '0197000024', role: 'boss' })).status, 400);

  // droits : le caissier vend mais ne gère pas le stock ; le magasinier gère le stock mais ne vend pas
  assert.equal((await push(cashier, 'stock.move', { id: 'b1', itemId: 'x1', delta: 1, kind: 'entree' })).status, 403);
  assert.equal((await push(keeper, 'sale.create', { entity: { id: 'sA', channelId: 'ch3', lines: [{ itemId: 'x1', qty: 1 }] } })).status, 403);
  assert.equal((await push(keeper, 'stock.move', { id: 'b2', itemId: 'x1', delta: 2, kind: 'entree' })).status, 200); // stock = 12
  assert.equal((await push(client, 'sale.create', { entity: { id: 'sB', channelId: 'ch3', lines: [{ itemId: 'x1', qty: 1 }] } })).status, 403);

  // vente en caisse : stock baissé, remise refusée au caissier
  assert.equal((await push(cashier, 'sale.create', { entity: { id: 's1', channelId: 'ch3', method: 'Mobile money', lines: [{ itemId: 'x1', qty: 2, unitPrice: 1 }, { itemId: 'x2', qty: 10 }] } })).status, 200);
  let cSnap = (await api('GET', '/sync/snapshot', null, cashier)).json;
  const s1 = cSnap.sales.find((s) => s.id === 's1');
  assert.equal(s1.total, 2 * 2000 + 10 * 100); // le prix envoyé par le caissier est ignoré
  assert.equal(cSnap.items.find((i) => i.id === 'x1').stock, 10);
  assert.equal(cSnap.items.find((i) => i.id === 'x1').cost, 0); // le caissier ne voit pas le prix d'achat
  assert.equal(cSnap.channels.find((c) => c.id === 'ch3').role, 'cashier');
  assert.equal(cSnap.purchases.length, 0);

  // le propriétaire voit tout et peut annuler une vente
  let oSnap = (await api('GET', '/sync/snapshot', null, owner)).json;
  assert.equal(oSnap.items.find((i) => i.id === 'x1').cost, 1000);
  assert.equal(oSnap.members.length, 2);
  assert.equal((await push(cashier, 'sale.void', { id: 's1' })).status, 403);
  assert.equal((await push(owner, 'sale.void', { id: 's1' })).status, 200);
  oSnap = (await api('GET', '/sync/snapshot', null, owner)).json;
  assert.equal(oSnap.items.find((i) => i.id === 'x1').stock, 12);
  assert.equal(oSnap.sales.find((s) => s.id === 's1').voided, true);

  // achat avec frais : coût moyen pondéré (12 en stock à 1000, +10 à 1000 + 20 % de frais)
  assert.equal((await push(keeper, 'purchase.create', { entity: { id: 'pu0', channelId: 'ch3', lines: [{ itemId: 'x1', qty: 1, unitCost: 1 }] } })).status, 403);
  assert.equal((await push(owner, 'purchase.create', { entity: { id: 'pu1', channelId: 'ch3', supplier: 'Guangzhou', extraCosts: 2000, lines: [{ itemId: 'x1', qty: 10, unitCost: 1000 }] } })).status, 200);
  oSnap = (await api('GET', '/sync/snapshot', null, owner)).json;
  assert.equal(oSnap.purchases[0].lines[0].landed, 1200);
  const x1 = oSnap.items.find((i) => i.id === 'x1');
  assert.equal(x1.stock, 22);
  assert.equal(x1.cost, Math.round((12 * 1000 + 10 * 1200) / 22));

  // réservation : stock retiré, annulation par la cliente = stock restitué
  assert.equal((await push(client, 'reservation.create', { id: 'r1', itemId: 'x1', qty: 30 })).status, 409);
  assert.equal((await push(client, 'reservation.create', { id: 'r1', itemId: 'x1', qty: 2, name: 'Cliente', phone: '0197000024' })).status, 200);
  assert.equal((await api('GET', '/sync/snapshot', null, owner)).json.items.find((i) => i.id === 'x1').stock, 20);
  assert.equal((await push(client, 'reservation.status', { id: 'r1', status: 'ready' })).status, 403);
  assert.equal((await push(cashier, 'reservation.status', { id: 'r1', status: 'ready' })).status, 200);
  assert.equal((await push(client, 'reservation.status', { id: 'r1', status: 'cancelled' })).status, 200);
  assert.equal((await api('GET', '/sync/snapshot', null, owner)).json.items.find((i) => i.id === 'x1').stock, 22);

  // réservation retirée = vente enregistrée ; réservation expirée = stock restitué
  await push(client, 'reservation.create', { id: 'r2', itemId: 'x2', qty: 5, name: 'Cliente' });
  assert.equal((await push(cashier, 'reservation.status', { id: 'r2', status: 'collected' })).status, 200);
  oSnap = (await api('GET', '/sync/snapshot', null, owner)).json;
  assert.equal(oSnap.sales.find((s) => s.id === 's_r2').total, 500);
  await push(client, 'reservation.create', { id: 'r3', itemId: 'x2', qty: 4, name: 'Cliente' });
  await db.query("UPDATE reservations SET expires_at = now() - interval '1 hour' WHERE id='r3'");
  const clSnap = (await api('GET', '/sync/snapshot', null, client)).json;
  assert.equal(clSnap.reservations.find((r) => r.id === 'r3').status, 'expired');
  assert.equal(clSnap.reservations.find((r) => r.id === 'r1').mine, true);
  const stylo = (await api('GET', '/sync/snapshot', null, owner)).json.items.find((i) => i.id === 'x2');
  assert.equal(stylo.stock, 100 - 5); // 5 retirés ; la réservation expirée est restituée

  // alerte « de retour en stock »
  await push(owner, 'stock.move', { id: 'c1', itemId: 'x2', delta: -95, kind: 'perte' });
  assert.equal((await push(client, 'alert.subscribe', { itemId: 'x2', value: true })).status, 200);
  await push(owner, 'stock.move', { id: 'c2', itemId: 'x2', delta: 20, kind: 'entree' });
  const notices = (await api('GET', '/sync/snapshot', null, client)).json.notices;
  assert.ok(notices.some((n) => n.title.startsWith('De retour')));

  // demande : termes recherchés mais absents, visibles du propriétaire seulement
  await push(client, 'demand.log', { channelId: 'ch3', term: 'Cartable Rose' });
  await push(client, 'demand.log', { channelId: 'ch3', term: 'cartable rose' });
  assert.equal((await api('GET', '/sync/snapshot', null, owner)).json.demand[0].count, 2);
  assert.equal((await api('GET', '/sync/snapshot', null, client)).json.demand.length, 0);

  // registre partagé : suggestion à partir du code-barres
  const sug = await api('GET', '/registry/7001', null, owner);
  assert.equal(sug.json.suggestion.name, 'Sac');
  assert.equal(sug.json.suggestion.usage, 'Porter des affaires');
  assert.equal((await api('GET', '/registry/0000', null, owner)).status, 404);
});
