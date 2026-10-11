import crypto from 'node:crypto';
import { config } from './config.js';
import { tx } from './db.js';
import { refundByReference } from './payments.js';
import { HttpError, int, str, url } from './util.js';

const uid = (p) => `${p}_${crypto.randomUUID()}`;
const notice = (q, userId, title, body = '') =>
  q.query('INSERT INTO notices (id,user_id,title,body) VALUES ($1,$2,$3,$4)', [uid('n'), userId, title, body]);

async function ownChannel(q, id, user) {
  const c = (await q.query('SELECT * FROM channels WHERE id=$1', [str(id, 80)])).rows[0];
  if (!c) throw new HttpError(404, 'Boutique introuvable');
  if (c.owner_id !== user.id) throw new HttpError(403, "Ce n'est pas ta boutique");
  return c;
}

const colorOf = (v, dflt) => {
  const n = Number(v);
  return Number.isInteger(n) && n >= 0 && n <= 0xffffffff ? n : dflt;
};

function postFields(e) {
  const type = int(e.type ?? 0, 0, 2);
  const text = str(e.text, 5000);
  const title = e.title ? str(e.title, 200).trim() : null;
  const price = e.price == null ? null : int(e.price, 1, 10_000_000);
  const stock = e.stock == null ? null : int(e.stock, 0, 1_000_000);
  if (title && price == null) throw new HttpError(400, 'Prix obligatoire pour un produit');
  if (!title && !text.trim() && !e.imageUrl && !e.videoUrl) throw new HttpError(400, 'Publication vide');
  const variants = Array.isArray(e.variants) ? e.variants.slice(0, 20).map((v) => str(String(v), 50)) : [];
  const extraUrls = Array.isArray(e.extraUrls) ? e.extraUrls.slice(0, 10).map(url).filter(Boolean) : [];
  return {
    type, time: str(e.time, 10), text, title, quote: e.quote ? str(e.quote, 300) : null,
    category: e.category ? str(e.category, 60) : null, price, stock, variants,
    color: colorOf(e.color, 4281545523), bold: !!e.bold, sold: !!e.sold || stock === 0,
    imageUrl: url(e.imageUrl), extraUrls, videoUrl: url(e.videoUrl), forwards: int(e.fw ?? 0, 0, 1_000_000),
  };
}

async function cancelOrder(q, o, lines) {
  for (const l of lines) {
    await q.query('UPDATE posts SET stock = stock + $2, sold = false WHERE id=$1 AND stock IS NOT NULL', [l.post_id, l.qty]);
  }
  const r = await refundByReference(q, o.ref);
  await q.query('UPDATE orders SET status=4, refunded=$2 WHERE ref=$1', [o.ref, !!r.ok]);
}

/** Solde d'une boutique : ventes livrées - commission - retraits (même calcul que l'app). */
async function balanceOf(q, channelId) {
  const rows = (
    await q.query(
      `SELECT o.ref, o.fees, COALESCE(SUM(l.unit_price*l.qty),0)::int AS items FROM orders o
       JOIN order_lines l ON l.order_ref=o.ref WHERE o.status=3 AND l.channel_id=$1 GROUP BY o.ref, o.fees`,
      [channelId],
    )
  ).rows;
  let earned = 0;
  for (const r of rows) {
    const fee = Number((r.fees || {})[channelId] || 0);
    earned += r.items + fee - Math.round(r.items * config.commissionRate);
  }
  const paid = Number((await q.query('SELECT COALESCE(SUM(amount),0)::int AS s FROM payouts WHERE channel_id=$1', [channelId])).rows[0].s);
  return earned - paid;
}

const handlers = {
  async 'store.create'(q, user, p) {
    const e = p.entity || {};
    const id = str(e.id, 80);
    if (!id) throw new HttpError(400, 'id manquant');
    const ex = (await q.query('SELECT owner_id FROM channels WHERE id=$1', [id])).rows[0];
    if (ex) {
      if (ex.owner_id !== user.id) throw new HttpError(403, 'Identifiant déjà pris');
      return;
    }
    const name = str(e.name, 80).trim();
    if (name.length < 3) throw new HttpError(400, 'Nom trop court');
    await q.query(
      `INSERT INTO channels (id, owner_id, name, description, category, zone, phone, color, logo_url, delivers, delivery_fee, created)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
      [id, user.id, name, str(e.description, 1000), str(e.category, 60), str(e.zone, 120), str(e.phone, 30), colorOf(e.color, 4278225275),
        url(e.logoUrl), !!e.delivers, int(e.deliveryFee ?? 0, 0, 1_000_000), str(e.created, 20)],
    );
  },

  async 'store.update'(q, user, p) {
    const e = p.entity || {};
    const c = await ownChannel(q, e.id, user);
    const name = str(e.name ?? c.name, 80).trim();
    if (name.length < 3) throw new HttpError(400, 'Nom trop court');
    await q.query(
      `UPDATE channels SET name=$2, description=$3, category=$4, zone=$5, phone=$6, color=$7, logo_url=$8, delivers=$9, delivery_fee=$10 WHERE id=$1`,
      [c.id, name, str(e.description, 1000), str(e.category, 60), str(e.zone, 120), str(e.phone, 30), colorOf(e.color, Number(c.color)),
        url(e.logoUrl) ?? c.logo_url, !!e.delivers, int(e.deliveryFee ?? 0, 0, 1_000_000)],
    );
  },

  async 'store.follow'(q, user, p) {
    const id = str(p.channelId, 80);
    if (p.followed) {
      await q.query('INSERT INTO follows (user_id, channel_id) SELECT $1, id FROM channels WHERE id=$2 ON CONFLICT DO NOTHING', [user.id, id]);
    } else {
      await q.query('DELETE FROM follows WHERE user_id=$1 AND channel_id=$2', [user.id, id]);
    }
  },

  async 'store.verify'(q, user, p) {
    if (!user.isAdmin) throw new HttpError(403, 'Réservé aux administrateurs');
    await q.query('UPDATE channels SET verified=$2 WHERE id=$1', [str(p.channelId, 80), !!p.verified]);
  },

  async 'post.create'(q, user, p) {
    const e = p.entity || {};
    const c = await ownChannel(q, p.channelId, user);
    const id = str(e.id ?? p.postId, 80);
    const ex = (await q.query('SELECT 1 FROM posts WHERE id=$1', [id])).rows[0];
    if (ex) return;
    const f = postFields(e);
    await q.query(
      `INSERT INTO posts (id, channel_id, type, time, text, title, quote, category, price, stock, variants, color, bold, sold, image_url, extra_urls, video_url, forwards)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12,$13,$14,$15,$16::jsonb,$17,$18)`,
      [id, c.id, f.type, f.time, f.text, f.title, f.quote, f.category, f.price, f.stock, JSON.stringify(f.variants), f.color, f.bold, f.sold,
        f.imageUrl, JSON.stringify(f.extraUrls), f.videoUrl, f.forwards],
    );
  },

  async 'post.update'(q, user, p) {
    const e = p.entity || {};
    const post = (await q.query('SELECT p.id, p.channel_id, p.image_url, p.video_url FROM posts p WHERE p.id=$1', [str(p.postId ?? e.id, 80)])).rows[0];
    if (!post) throw new HttpError(404, 'Publication introuvable');
    await ownChannel(q, post.channel_id, user);
    const f = postFields(e);
    await q.query(
      `UPDATE posts SET type=$2, text=$3, title=$4, quote=$5, category=$6, price=$7, stock=$8, variants=$9::jsonb, color=$10, bold=$11, sold=$12,
         image_url=COALESCE($13, image_url), extra_urls=$14::jsonb, video_url=COALESCE($15, video_url) WHERE id=$1`,
      [post.id, f.type, f.text, f.title, f.quote, f.category, f.price, f.stock, JSON.stringify(f.variants), f.color, f.bold, f.sold, f.imageUrl,
        JSON.stringify(f.extraUrls), f.videoUrl],
    );
  },

  async 'post.delete'(q, user, p) {
    const post = (await q.query('SELECT channel_id FROM posts WHERE id=$1', [str(p.postId, 80)])).rows[0];
    if (!post) return;
    await ownChannel(q, post.channel_id, user);
    await q.query('DELETE FROM posts WHERE id=$1', [str(p.postId, 80)]);
  },

  async 'post.react'(q, user, p) {
    const id = str(p.postId, 80);
    if (p.emoji == null) {
      await q.query('DELETE FROM post_reactions WHERE post_id=$1 AND user_id=$2', [id, user.id]);
    } else {
      await q.query(
        `INSERT INTO post_reactions (post_id, user_id, emoji) SELECT id, $2, $3 FROM posts WHERE id=$1
         ON CONFLICT (post_id, user_id) DO UPDATE SET emoji=$3`,
        [id, user.id, str(p.emoji, 8)],
      );
    }
  },

  async 'favorite.set'(q, user, p) {
    const id = str(p.postId, 80);
    if (p.value) {
      await q.query('INSERT INTO favorites (user_id, post_id) SELECT $1, id FROM posts WHERE id=$2 ON CONFLICT DO NOTHING', [user.id, id]);
    } else {
      await q.query('DELETE FROM favorites WHERE user_id=$1 AND post_id=$2', [user.id, id]);
    }
  },

  async 'order.create'(q, user, p) {
    const e = p.entity || {};
    const ref = str(e.ref, 64);
    if (ref.length < 3) throw new HttpError(400, 'Référence invalide');
    if ((await q.query('SELECT 1 FROM orders WHERE ref=$1', [ref])).rows.length) return; // idempotent
    const lines = Array.isArray(e.lines) ? e.lines : [];
    if (!lines.length || lines.length > 50) throw new HttpError(400, 'Panier invalide');
    const delivery = !!e.delivery;
    const address = str(e.address, 300);
    if (delivery && !address.trim()) throw new HttpError(400, 'Adresse de livraison obligatoire');

    let items = 0;
    const resolved = [];
    const chans = new Map();
    for (const l of lines) {
      const qty = int(l.q, 1, 99);
      const post = (
        await q.query(
          `SELECT p.*, c.delivers, c.delivery_fee, c.owner_id FROM posts p JOIN channels c ON c.id=p.channel_id WHERE p.id=$1`,
          [str(l.p, 80)],
        )
      ).rows[0];
      if (!post || post.price == null) throw new HttpError(404, 'Produit introuvable');
      if (post.sold) throw new HttpError(409, `« ${post.title} » est terminé`);
      if (post.owner_id === user.id && !config.allowSelfPurchase) throw new HttpError(403, 'Tu ne peux pas acheter dans ta propre boutique');
      const variant = str(l.v ?? '', 50);
      if ((post.variants || []).length && !post.variants.includes(variant)) throw new HttpError(400, `Choisis une option pour « ${post.title} »`);
      if (post.stock != null) {
        const r = await q.query('UPDATE posts SET stock = stock - $2, sold = (stock - $2) <= 0 WHERE id=$1 AND stock >= $2 RETURNING stock', [post.id, qty]);
        if (!r.rows.length) throw new HttpError(409, `Stock insuffisant pour « ${post.title} »`);
      }
      items += post.price * qty;
      chans.set(post.channel_id, { fee: post.delivery_fee, delivers: post.delivers, owner: post.owner_id });
      resolved.push({ channel_id: post.channel_id, post_id: post.id, title: post.title, unit_price: post.price, qty, variant });
    }
    const fees = {};
    let feeTotal = 0;
    if (delivery) {
      for (const [cid, c] of chans) {
        if (!c.delivers) throw new HttpError(400, 'Une boutique du panier ne propose pas la livraison');
        fees[cid] = c.fee;
        feeTotal += c.fee;
      }
    }
    const total = items + feeTotal;
    const pay = (await q.query('SELECT * FROM payments WHERE reference=$1', [ref])).rows[0];
    if (!pay || pay.user_id !== user.id || pay.status !== 'succeeded' || pay.amount !== total) {
      throw new HttpError(402, 'Paiement introuvable ou montant incorrect');
    }
    await q.query(
      `INSERT INTO orders (ref, buyer_id, provider, phone, buyer_name, address, delivery, status, items_total, fee_total, total, fees)
       VALUES ($1,$2,$3,$4,$5,$6,$7,0,$8,$9,$10,$11::jsonb)`,
      [ref, user.id, pay.provider, pay.phone, user.name, address, delivery, items, feeTotal, total, JSON.stringify(fees)],
    );
    for (const l of resolved) {
      await q.query('INSERT INTO order_lines (order_ref, channel_id, post_id, title, unit_price, qty, variant) VALUES ($1,$2,$3,$4,$5,$6,$7)',
        [ref, l.channel_id, l.post_id, l.title, l.unit_price, l.qty, l.variant]);
    }
    await notice(q, user.id, `Commande ${ref} payée`, `${total} FCFA via ${pay.provider}`);
    for (const c of chans.values()) {
      if (c.owner !== user.id) await notice(q, c.owner, `Nouvelle commande ${ref}`, `${user.name} · ${total} FCFA`);
    }
  },

  async 'order.status'(q, user, p) {
    const o = (await q.query('SELECT * FROM orders WHERE ref=$1', [str(p.ref, 64)])).rows[0];
    if (!o) throw new HttpError(404, 'Commande introuvable');
    const lines = (await q.query('SELECT * FROM order_lines WHERE order_ref=$1', [o.ref])).rows;
    const owners = (await q.query('SELECT DISTINCT c.owner_id FROM order_lines l JOIN channels c ON c.id=l.channel_id WHERE l.order_ref=$1', [o.ref])).rows.map((r) => r.owner_id);
    const isBuyer = o.buyer_id === user.id;
    const isSeller = owners.includes(user.id);
    const target = int(p.status, 0, 4);
    if (target === o.status) return;
    if (target === 4) {
      if (o.status >= 3) throw new HttpError(409, 'Commande déjà livrée ou annulée');
      if (!(isSeller || (isBuyer && o.status === 0))) throw new HttpError(403, 'Annulation non autorisée');
      await cancelOrder(q, o, lines);
      await notice(q, isBuyer ? o.buyer_id : o.buyer_id, `Commande ${o.ref} annulée`, 'Remboursement en cours');
      for (const ow of owners) if (ow !== user.id) await notice(q, ow, `Commande ${o.ref} annulée`);
      return;
    }
    if (!isSeller) throw new HttpError(403, 'Réservé à la boutique');
    if (o.status >= 3 || target !== o.status + 1) throw new HttpError(409, 'Changement de statut invalide');
    await q.query('UPDATE orders SET status=$2 WHERE ref=$1', [o.ref, target]);
    await notice(q, o.buyer_id, `Commande ${o.ref}`, ['', 'Confirmée par la boutique', 'Prête', 'Livrée'][target]);
  },

  async 'review.create'(q, user, p) {
    const e = p.entity || {};
    const rating = int(e.rating, 1, 5);
    const postId = str(e.postId, 80);
    const ok = (
      await q.query(
        `SELECT o.ref, l.channel_id FROM orders o JOIN order_lines l ON l.order_ref=o.ref
         WHERE o.buyer_id=$1 AND o.status=3 AND l.post_id=$2
           AND NOT EXISTS (SELECT 1 FROM order_reviewed r WHERE r.order_ref=o.ref AND r.post_id=l.post_id) LIMIT 1`,
        [user.id, postId],
      )
    ).rows[0];
    if (!ok) throw new HttpError(403, 'Avis possible uniquement après livraison, une fois par commande');
    await q.query('INSERT INTO reviews (id, channel_id, post_id, author_id, author, rating, text) VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (id) DO NOTHING',
      [str(e.id, 80) || uid('r'), ok.channel_id, postId, user.id, user.name, rating, str(e.text, 1000)]);
    await q.query('INSERT INTO order_reviewed (order_ref, post_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [ok.ref, postId]);
    const owner = (await q.query('SELECT owner_id FROM channels WHERE id=$1', [ok.channel_id])).rows[0];
    if (owner) await notice(q, owner.owner_id, 'Nouvel avis', `${rating}/5 de ${user.name}`);
  },

  async 'report.create'(q, user, p) {
    const id = str(p.channelId, 80);
    if (!(await q.query('SELECT 1 FROM channels WHERE id=$1', [id])).rows.length) throw new HttpError(404, 'Boutique introuvable');
    await q.query('INSERT INTO reports (channel_id, reporter_id, reporter_name, reason) VALUES ($1,$2,$3,$4)', [id, user.id, user.name, str(p.reason, 300)]);
  },

  async 'payout.request'(q, user, p) {
    const e = p.entity || {};
    const c = await ownChannel(q, e.channelId, user);
    const amount = int(e.amount, 1, 100_000_000);
    if (amount < config.minPayout) throw new HttpError(400, `Minimum ${config.minPayout} FCFA`);
    const id = str(e.id, 80) || uid('p');
    if ((await q.query('SELECT 1 FROM payouts WHERE id=$1', [id])).rows.length) return;
    if (amount > (await balanceOf(q, c.id))) throw new HttpError(400, 'Solde insuffisant');
    await q.query('INSERT INTO payouts (id, channel_id, user_id, amount, phone) VALUES ($1,$2,$3,$4,$5)', [id, c.id, user.id, amount, str(e.phone, 30)]);
    await notice(q, user.id, 'Retrait demandé', `${amount} FCFA vers ${e.phone || ''}`);
  },

  async 'address.save'(q, user, p) {
    const e = p.entity || {};
    await q.query(
      `INSERT INTO addresses (id, user_id, label, text) VALUES ($1,$2,$3,$4)
       ON CONFLICT (id) DO UPDATE SET label=$3, text=$4 WHERE addresses.user_id=$2`,
      [str(e.id, 80), user.id, str(e.label, 60), str(e.text, 300)],
    );
  },

  async 'address.delete'(q, user, p) {
    await q.query('DELETE FROM addresses WHERE id=$1 AND user_id=$2', [str(p.id, 80), user.id]);
  },

  async 'account.update'(q, user, p) {
    const name = str(p.name, 80).trim();
    if (name.length >= 2) await q.query('UPDATE users SET name=$2 WHERE id=$1', [user.id, name]); // le téléphone change via POST /me/phone
  },

  async 'device.register'(q, user, p) {
    await q.query(
      `INSERT INTO device_tokens (token, user_id, platform) VALUES ($1,$2,$3)
       ON CONFLICT (token) DO UPDATE SET user_id=$2, platform=$3`,
      [str(p.token, 400), user.id, str(p.platform, 20)],
    );
  },
};

/** Applique une opération de synchronisation, de façon atomique et idempotente. */
export async function applyOp(user, op) {
  if (!op || typeof op.id !== 'string' || typeof op.type !== 'string') throw new HttpError(400, 'Opération invalide');
  const handler = handlers[op.type];
  if (!handler) throw new HttpError(400, `Type d'opération inconnu : ${op.type}`);
  await tx(async (q) => {
    const ins = await q.query('INSERT INTO ops (id, user_id, type) VALUES ($1,$2,$3) ON CONFLICT (id) DO NOTHING RETURNING id', [`${user.id}:${op.id}`, user.id, op.type]);
    if (!ins.rows.length) return; // déjà appliquée
    await handler(q, user, op.payload || {});
  });
}
