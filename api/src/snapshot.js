import { db } from './db.js';
import { addressJson, channelJson, noticeJson, orderJson, payoutJson, postJson, reportJson, reviewJson } from './serializers.js';

/** Boutiques (avec publications) vues par `user` ; onlyId limite à une boutique. */
export async function buildChannels(user, onlyId = null) {
  const uid = user ? user.id : '';
  const chs = (
    await db.query(
      `SELECT c.*, (SELECT count(*)::int FROM follows f WHERE f.channel_id=c.id) AS followers,
              EXISTS (SELECT 1 FROM follows f WHERE f.channel_id=c.id AND f.user_id=$1) AS followed
       FROM channels c WHERE ($2::text IS NULL OR c.id=$2) ORDER BY c.created_at DESC LIMIT 500`,
      [uid, onlyId],
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
  if (user.isAdmin) snap.reports = (await db.query('SELECT * FROM reports ORDER BY created_at DESC LIMIT 500')).rows.map(reportJson);
  return snap;
}
