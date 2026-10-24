import { db, tx } from './db.js';
import { expireReservations } from './ops.js';
import { addressJson, catalogItemJson, channelJson, demandJson, groupJson, memberJson, movementJson, purchaseJson, reservationJson, saleJson, noticeJson, orderJson, payoutJson, postJson, reportJson, reviewJson } from './serializers.js';

/** Boutiques (avec publications) vues par `user` ; onlyId limite à une boutique. */
export async function buildChannels(user, onlyId = null) {
  const uid = user ? user.id : '';
  const phone = user ? user.phone : '';
  const chs = (
    await db.query(
      `SELECT c.*, (SELECT count(*)::int FROM follows f WHERE f.channel_id=c.id) AS followers,
              EXISTS (SELECT 1 FROM follows f WHERE f.channel_id=c.id AND f.user_id=$1) AS followed,
              (SELECT cm.role FROM channel_members cm WHERE cm.channel_id=c.id AND cm.phone=$3) AS member_role
       FROM channels c WHERE ($2::text IS NULL OR c.id=$2) ORDER BY c.created_at DESC LIMIT 500`,
      [uid, onlyId, phone],
    )
  ).rows;
  const posts = (
    await db.query(
      `SELECT * FROM (SELECT p.*, row_number() OVER (PARTITION BY p.channel_id ORDER BY p.created_at DESC) AS rn FROM posts p
                      WHERE ($1::text IS NULL OR p.channel_id=$1)) t WHERE rn <= 200 ORDER BY created_at ASC`,
      [onlyId],
    )
  ).rows;
  const reacts = (
    await db.query(
      `SELECT r.post_id, r.emoji, count(*)::int AS c FROM post_reactions r JOIN posts p ON p.id=r.post_id
       WHERE ($1::text IS NULL OR p.channel_id=$1) GROUP BY r.post_id, r.emoji ORDER BY c DESC`,
      [onlyId],
    )
  ).rows;
  const mine = (
    await db.query(`SELECT r.post_id, r.emoji FROM post_reactions r JOIN posts p ON p.id=r.post_id WHERE r.user_id=$1 AND ($2::text IS NULL OR p.channel_id=$2)`, [uid, onlyId])
  ).rows;
  const myMap = new Map(mine.map((r) => [r.post_id, r.emoji]));
  const byPost = new Map();
  for (const r of reacts) byPost.set(r.post_id, [...(byPost.get(r.post_id) || []), r]);
  const byChannel = new Map();
  for (const p of posts) byChannel.set(p.channel_id, [...(byChannel.get(p.channel_id) || []), postJson(p, byPost.get(p.id) || [], myMap.get(p.id) || null)]);
  return chs.map((c) => channelJson(c, user, byChannel.get(c.id) || []));
}

const ORDER_COND = `(o.buyer_id=$1 OR EXISTS (SELECT 1 FROM order_lines l JOIN channels c ON c.id=l.channel_id WHERE l.order_ref=o.ref AND c.owner_id=$1))`;

/** État complet de l'utilisateur, au même format que le fichier local de l'app. */
export async function buildSnapshot(user) {
  const channels = await buildChannels(user);
  const orders = (await db.query(`SELECT o.* FROM orders o WHERE ${ORDER_COND} ORDER BY o.created_at DESC LIMIT 300`, [user.id])).rows;
  const lines = (await db.query(`SELECT l.* FROM order_lines l JOIN orders o ON o.ref=l.order_ref WHERE ${ORDER_COND} ORDER BY l.id`, [user.id])).rows;
  const revd = (await db.query(`SELECT r.* FROM order_reviewed r JOIN orders o ON o.ref=r.order_ref WHERE ${ORDER_COND}`, [user.id])).rows;
  const reviews = (await db.query('SELECT * FROM reviews ORDER BY created_at DESC LIMIT 2000')).rows;
  const addresses = (await db.query('SELECT * FROM addresses WHERE user_id=$1', [user.id])).rows;
  const payouts = (await db.query('SELECT * FROM payouts WHERE user_id=$1 ORDER BY created_at DESC', [user.id])).rows;
  const notices = (await db.query('SELECT * FROM notices WHERE user_id=$1 ORDER BY created_at DESC LIMIT 100', [user.id])).rows;
  const favs = (await db.query('SELECT post_id FROM favorites WHERE user_id=$1', [user.id])).rows;
  const snap = {
    v: 1,
    channels,
    orders: orders.map((o) => orderJson(o, lines.filter((l) => l.order_ref === o.ref), revd.filter((r) => r.order_ref === o.ref).map((r) => r.post_id))),
    reviews: reviews.map(reviewJson),
    addresses: addresses.map(addressJson),
    payouts: payouts.map(payoutJson),
    notices: notices.map(noticeJson),
    favorites: favs.map((f) => f.post_id),
  };
  const P = [user.id, user.phone];
  const MEMBER = (roles) => `EXISTS (SELECT 1 FROM channel_members cm WHERE cm.channel_id=c.id AND cm.phone=$2 AND cm.role IN (${roles.map((r) => `'${r}'`).join(',')}))`;
  const ANYSTAFF = `(c.owner_id=$1 OR ${MEMBER(['manager', 'cashier', 'stock'])})`;
  const VIS = `(c.owner_id=$1 OR EXISTS (SELECT 1 FROM follows f WHERE f.channel_id=c.id AND f.user_id=$1) OR ${MEMBER(['manager', 'cashier', 'stock'])})`;
  const MGR = `(c.owner_id=$1 OR ${MEMBER(['manager'])})`;
  const STK = `(c.owner_id=$1 OR ${MEMBER(['manager', 'stock'])})`;
  await tx((q) => expireReservations(q));
  snap.groups = (await db.query(`SELECT g.* FROM catalog_groups g JOIN channels c ON c.id=g.channel_id WHERE ${VIS}`, P)).rows.map(groupJson);
  snap.items = (
    await db.query(
      `SELECT i.*, CASE WHEN c.owner_id=$1 THEN 'owner' ELSE (SELECT cm.role FROM channel_members cm WHERE cm.channel_id=c.id AND cm.phone=$2) END AS role
       FROM catalog_items i JOIN channels c ON c.id=i.channel_id WHERE i.active AND ${VIS}`,
      P,
    )
  ).rows.map((r) => catalogItemJson(r, r.role));
  snap.movements = (await db.query(`SELECT m.* FROM stock_movements m JOIN channels c ON c.id=m.channel_id WHERE ${STK} ORDER BY m.created_at DESC LIMIT 500`, P)).rows.map(movementJson);
  snap.blankCodes = (await db.query(`SELECT b.* FROM catalog_codes b JOIN channels c ON c.id=b.channel_id WHERE ${STK}`, P)).rows.map((r) => ({ channelId: r.channel_id, code: r.code }));
  const sales = (await db.query(`SELECT s.* FROM sales s JOIN channels c ON c.id=s.channel_id WHERE ${MGR} OR s.cashier_id=$1 ORDER BY s.created_at DESC LIMIT 1000`, P)).rows;
  const saleLines = (await db.query(`SELECT l.* FROM sale_lines l JOIN sales s ON s.id=l.sale_id JOIN channels c ON c.id=s.channel_id WHERE ${MGR} OR s.cashier_id=$1 ORDER BY l.id`, P)).rows;
  snap.sales = sales.map((s) => saleJson(s, saleLines.filter((l) => l.sale_id === s.id)));
  const purchases = (await db.query(`SELECT p.* FROM purchases p JOIN channels c ON c.id=p.channel_id WHERE ${MGR} ORDER BY p.created_at DESC LIMIT 300`, P)).rows;
  const pLines = (await db.query(`SELECT l.* FROM purchase_lines l JOIN purchases p ON p.id=l.purchase_id JOIN channels c ON c.id=p.channel_id WHERE ${MGR} ORDER BY l.id`, P)).rows;
  snap.purchases = purchases.map((p) => purchaseJson(p, pLines.filter((l) => l.purchase_id === p.id)));
  snap.reservations = (
    await db.query(
      `SELECT r.*, (SELECT i.name FROM catalog_items i WHERE i.id=r.item_id) AS item_name FROM reservations r JOIN channels c ON c.id=r.channel_id
       WHERE ${ANYSTAFF} OR r.user_id=$1 ORDER BY r.created_at DESC LIMIT 500`,
      P,
    )
  ).rows.map((r) => reservationJson(r, user.id));
  snap.members = (await db.query(`SELECT m.* FROM channel_members m JOIN channels c ON c.id=m.channel_id WHERE c.owner_id=$1`, [user.id])).rows.map(memberJson);
  snap.demand = (await db.query(`SELECT d.* FROM demand_terms d JOIN channels c ON c.id=d.channel_id WHERE ${MGR} ORDER BY d.count DESC LIMIT 200`, P)).rows.map(demandJson);
  snap.alerts = (await db.query('SELECT item_id FROM stock_alerts WHERE user_id=$1', [user.id])).rows.map((r) => r.item_id);
  if (user.isAdmin) snap.reports = (await db.query('SELECT * FROM reports ORDER BY created_at DESC LIMIT 500')).rows.map(reportJson);
  return snap;
}

/** Cherche un produit par code court d'étiquette ou code-barres dans une boutique. */
export async function findItem(channelId, raw) {
  return (
    await db.query(`SELECT * FROM catalog_items WHERE channel_id=$1 AND active AND (code=$2 OR barcodes @> $3::jsonb)`, [channelId, String(raw).toUpperCase(), JSON.stringify([String(raw)])])
  ).rows[0];
}
