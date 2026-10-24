import crypto from 'node:crypto';
import { config } from './config.js';
import { tx } from './db.js';
import { refundByReference } from './payments.js';
import { HttpError, int, normalizePhone, str, url } from './util.js';

const uid = (p) => `${p}_${crypto.randomUUID()}`;
const notice = (q, userId, title, body = '') =>
  q.query('INSERT INTO notices (id,user_id,title,body) VALUES ($1,$2,$3,$4)', [uid('n'), userId, title, body]);

const MANAGE = ['owner', 'manager'];
const CAT = ['owner', 'manager', 'stock'];
const SELL = ['owner', 'manager', 'cashier'];
const PAY_METHODS = ['Espèces', 'Mobile money', 'Autre'];

/** Rôle de l'utilisateur dans une boutique : owner | manager | cashier | stock | null. */
async function roleIn(q, channelId, user) {
  const c = (await q.query('SELECT owner_id FROM channels WHERE id=$1', [str(channelId, 80)])).rows[0];
  if (!c) throw new HttpError(404, 'Boutique introuvable');
  if (c.owner_id === user.id) return 'owner';
  const m = (await q.query('SELECT role FROM channel_members WHERE channel_id=$1 AND phone=$2', [str(channelId, 80), user.phone])).rows[0];
  return m ? m.role : null;
}

async function staffChannel(q, id, user, allowed) {
  const role = await roleIn(q, id, user);
  if (!role || !allowed.includes(role)) throw new HttpError(403, 'Action non autorisée pour ton rôle');
  const c = (await q.query('SELECT * FROM channels WHERE id=$1', [str(id, 80)])).rows[0];
  return { ...c, role };
}

/** Mouvement de stock unique : produit, historique, publication en ligne liée, alertes « de retour en stock ». */
async function applyStock(q, it, delta, kind, note = '', by = '', id = null) {
  const before = Number(it.stock);
  const after = Math.max(0, before + delta);
  await q.query('UPDATE catalog_items SET stock=$2 WHERE id=$1', [it.id, after]);
  await q.query(
    'INSERT INTO stock_movements (id, item_id, channel_id, delta, kind, note, by_name, balance_after) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT (id) DO NOTHING',
    [id || uid('m'), it.id, it.channel_id, after - before, kind, note, by, after],
  );
  if (it.post_id) await q.query('UPDATE posts SET stock=$2, sold=($2<=0) WHERE id=$1', [it.post_id, after]);
  if (before <= 0 && after > 0) {
    const subs = (await q.query('SELECT user_id FROM stock_alerts WHERE item_id=$1', [it.id])).rows;
    for (const sub of subs) await notice(q, sub.user_id, `De retour : ${it.name}`, 'Ce produit est de nouveau disponible.');
    await q.query('DELETE FROM stock_alerts WHERE item_id=$1', [it.id]);
  }
  it.stock = after;
  return after;
}

const freshItem = async (q, id) => (await q.query('SELECT * FROM catalog_items WHERE id=$1', [id])).rows[0];

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

const KINDS = ['entree', 'vente', 'perte', 'retour', 'inventaire', 'vente_en_ligne', 'initial', 'reservation'];

/** Répercute un mouvement de stock d'une publication en ligne sur le produit de catalogue lié. */
async function mirrorToCatalog(q, postId, delta, kind, by = '') {
  const it = (await q.query('SELECT * FROM catalog_items WHERE post_id=$1 AND active', [postId])).rows[0];
  if (it) await applyStock(q, it, delta, kind, '', by);
}

async function cancelOrder(q, o, lines) {
  for (const l of lines) {
    await q.query('UPDATE posts SET stock = stock + $2, sold = false WHERE id=$1 AND stock IS NOT NULL', [l.post_id, l.qty]);
    await mirrorToCatalog(q, l.post_id, l.qty, 'retour');
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
    const c = await staffChannel(q, p.channelId, user, MANAGE);
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
    await staffChannel(q, post.channel_id, user, MANAGE);
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
    await staffChannel(q, post.channel_id, user, MANAGE);
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
        await mirrorToCatalog(q, post.id, -qty, 'vente_en_ligne', user.name);
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

  async 'catalog.group.save'(q, user, p) {
    const e = p.entity || {};
    const c = await staffChannel(q, e.channelId, user, CAT);
    const id = str(e.id, 80);
    const name = str(e.name, 80).trim();
    const parent = e.parentId ? str(e.parentId, 80) : null;
    if (!id || !name || parent === id) throw new HttpError(400, 'Sous-catalogue invalide');
    if (parent && !(await q.query('SELECT 1 FROM catalog_groups WHERE id=$1 AND channel_id=$2', [parent, c.id])).rows.length) throw new HttpError(400, 'Dossier parent introuvable');
    const ex = (await q.query('SELECT channel_id FROM catalog_groups WHERE id=$1', [id])).rows[0];
    if (ex && ex.channel_id !== c.id) throw new HttpError(403, 'Identifiant déjà pris');
    if (ex) await q.query('UPDATE catalog_groups SET name=$2, parent_id=$3 WHERE id=$1', [id, name, parent]);
    else await q.query('INSERT INTO catalog_groups (id, channel_id, parent_id, name) VALUES ($1,$2,$3,$4)', [id, c.id, parent, name]);
  },

  async 'catalog.group.delete'(q, user, p) {
    const g = (await q.query('SELECT * FROM catalog_groups WHERE id=$1', [str(p.id, 80)])).rows[0];
    if (!g) return;
    await staffChannel(q, g.channel_id, user, CAT);
    await q.query('UPDATE catalog_groups SET parent_id=$2 WHERE parent_id=$1', [g.id, g.parent_id]);
    await q.query('UPDATE catalog_items SET group_id=$2 WHERE group_id=$1', [g.id, g.parent_id]);
    await q.query('DELETE FROM catalog_groups WHERE id=$1', [g.id]);
  },

  async 'catalog.codes.create'(q, user, p) {
    const c = await staffChannel(q, p.channelId, user, CAT);
    const codes = Array.isArray(p.codes) ? p.codes.slice(0, 500).map((x) => str(x, 20).toUpperCase()) : [];
    for (const code of codes) {
      if (!/^[A-Z0-9-]{4,20}$/.test(code)) throw new HttpError(400, 'Code invalide');
      const used = (await q.query('SELECT 1 FROM catalog_items WHERE channel_id=$1 AND code=$2', [c.id, code])).rows.length;
      if (!used) await q.query('INSERT INTO catalog_codes (channel_id, code) VALUES ($1,$2) ON CONFLICT DO NOTHING', [c.id, code]);
    }
  },

  async 'catalog.item.save'(q, user, p) {
    const e = p.entity || {};
    const c = await staffChannel(q, e.channelId, user, CAT);
    const id = str(e.id, 80);
    const name = str(e.name, 200).trim();
    const code = str(e.code, 20).toUpperCase();
    if (!id || !name) throw new HttpError(400, 'Produit invalide');
    if (!/^[A-Z0-9-]{4,20}$/.test(code)) throw new HttpError(400, 'Code invalide');
    const ex = (await q.query('SELECT channel_id FROM catalog_items WHERE id=$1', [id])).rows[0];
    if (ex && ex.channel_id !== c.id) throw new HttpError(403, 'Identifiant déjà pris');
    if ((await q.query('SELECT 1 FROM catalog_items WHERE channel_id=$1 AND code=$2 AND id<>$3 AND active', [c.id, code, id])).rows.length) {
      throw new HttpError(409, 'Ce code est déjà utilisé par un autre produit');
    }
    const barcodes = Array.isArray(e.barcodes) ? [...new Set(e.barcodes.slice(0, 10).map((b) => str(b, 64).trim()).filter(Boolean))] : [];
    for (const b of barcodes) {
      if ((await q.query('SELECT 1 FROM catalog_items WHERE channel_id=$1 AND id<>$2 AND active AND barcodes @> $3::jsonb', [c.id, id, JSON.stringify([b])])).rows.length) {
        throw new HttpError(409, `Le code-barres ${b} appartient déjà à un autre produit`);
      }
    }
    const groupId = e.groupId ? str(e.groupId, 80) : null;
    if (groupId && !(await q.query('SELECT 1 FROM catalog_groups WHERE id=$1 AND channel_id=$2', [groupId, c.id])).rows.length) throw new HttpError(400, 'Sous-catalogue introuvable');
    const postId = e.postId ? str(e.postId, 80) : null;
    const details = Array.isArray(e.details) ? e.details.slice(0, 30).map((d) => [str(d?.[0], 80), str(d?.[1], 300)]) : [];
    const f = [
      groupId, code, JSON.stringify(barcodes), name, str(e.description, 3000), str(e.usage, 3000), JSON.stringify(details), str(e.location, 80),
      str(e.unit || 'pièce', 20), str(e.variant, 80), e.category ? str(e.category, 60) : null, int(e.price ?? 0, 0, 100_000_000),
      int(e.cost ?? 0, 0, 100_000_000), int(e.lowStock ?? 3, 0, 1_000_000), JSON.stringify(Array.isArray(e.imageUrls) ? e.imageUrls.slice(0, 10).map(url).filter(Boolean) : []),
      postId, e.active !== false,
    ];
    if (ex) {
      await q.query(
        `UPDATE catalog_items SET group_id=$2, code=$3, barcodes=$4::jsonb, name=$5, description=$6, usage=$7, details=$8::jsonb, location=$9, unit=$10,
           variant=$11, category=$12, price=$13, cost=$14, low_stock=$15, image_urls=$16::jsonb, post_id=$17, active=$18 WHERE id=$1`,
        [id, ...f],
      ); // le stock n'est jamais écrasé : il ne change que par mouvements (stock.move)
    } else {
      await q.query(
        `INSERT INTO catalog_items (id, channel_id, group_id, code, barcodes, name, description, usage, details, location, unit, variant, category, price, cost, low_stock, image_urls, post_id, active)
         VALUES ($1,$19,$2,$3,$4::jsonb,$5,$6,$7,$8::jsonb,$9,$10,$11,$12,$13,$14,$15,$16::jsonb,$17,$18)`,
        [id, ...f, c.id],
      );
    }
    await q.query('DELETE FROM catalog_codes WHERE channel_id=$1 AND code=$2', [c.id, code]);
    for (const b of barcodes) {
      await q.query(
        `INSERT INTO product_registry (barcode, name, description, usage, image_url) VALUES ($1,$2,$3,$4,$5)
         ON CONFLICT (barcode) DO UPDATE SET uses = product_registry.uses + 1,
           name = CASE WHEN product_registry.name = '' THEN EXCLUDED.name ELSE product_registry.name END,
           description = CASE WHEN product_registry.description = '' THEN EXCLUDED.description ELSE product_registry.description END,
           usage = CASE WHEN product_registry.usage = '' THEN EXCLUDED.usage ELSE product_registry.usage END,
           image_url = COALESCE(product_registry.image_url, EXCLUDED.image_url), updated_at = now()`,
        [b, name, str(e.description, 3000), str(e.usage, 3000), (Array.isArray(e.imageUrls) ? e.imageUrls.map(url).filter(Boolean)[0] : null) || null],
      );
    }
  },

  async 'catalog.item.delete'(q, user, p) {
    const it = (await q.query('SELECT channel_id FROM catalog_items WHERE id=$1', [str(p.id, 80)])).rows[0];
    if (!it) return;
    await staffChannel(q, it.channel_id, user, CAT);
    await q.query('UPDATE catalog_items SET active=false, post_id=NULL WHERE id=$1', [str(p.id, 80)]);
  },

  async 'stock.move'(q, user, p) {
    const it = await freshItem(q, str(p.itemId, 80));
    if (!it) throw new HttpError(404, 'Produit introuvable');
    await staffChannel(q, it.channel_id, user, CAT);
    const delta = int(p.delta, -1_000_000, 1_000_000);
    const kind = str(p.kind, 30);
    if (!KINDS.includes(kind)) throw new HttpError(400, 'Motif de mouvement inconnu');
    await applyStock(q, it, delta, kind, str(p.note, 300), user.name, str(p.id, 80) || null);
  },

  async 'team.invite'(q, user, p) {
    const c = await ownChannel(q, p.channelId, user);
    const phone = normalizePhone(p.phone);
    const role = str(p.role, 20);
    if (phone.length < 8) throw new HttpError(400, 'Numéro invalide');
    if (!['manager', 'cashier', 'stock'].includes(role)) throw new HttpError(400, 'Rôle inconnu');
    if (phone === user.phone) throw new HttpError(400, "C'est ton propre numéro");
    await q.query(
      `INSERT INTO channel_members (channel_id, phone, name, role) VALUES ($1,$2,$3,$4)
       ON CONFLICT (channel_id, phone) DO UPDATE SET name=$3, role=$4`,
      [c.id, phone, str(p.name, 80), role],
    );
    const u = (await q.query('SELECT id FROM users WHERE phone=$1 AND deleted_at IS NULL', [phone])).rows[0];
    if (u) await notice(q, u.id, `Invitation : ${c.name}`, `Tu as été ajouté(e) à l'équipe de cette boutique.`);
  },

  async 'team.remove'(q, user, p) {
    const c = await ownChannel(q, p.channelId, user);
    await q.query('DELETE FROM channel_members WHERE channel_id=$1 AND phone=$2', [c.id, normalizePhone(p.phone)]);
  },

  async 'sale.create'(q, user, p) {
    const e = p.entity || {};
    const c = await staffChannel(q, e.channelId, user, SELL);
    const id = str(e.id, 80);
    if (!id) throw new HttpError(400, 'Vente invalide');
    if ((await q.query('SELECT 1 FROM sales WHERE id=$1', [id])).rows.length) return;
    const lines = Array.isArray(e.lines) ? e.lines : [];
    if (!lines.length || lines.length > 100) throw new HttpError(400, 'Vente vide');
    let total = 0;
    let costTotal = 0;
    const resolved = [];
    for (const l of lines) {
      const it = await freshItem(q, str(l.itemId, 80));
      if (!it || it.channel_id !== c.id || !it.active) throw new HttpError(404, 'Produit introuvable');
      const qty = int(l.qty, 1, 9999);
      const price = MANAGE.includes(c.role) && l.unitPrice != null ? int(l.unitPrice, 0, 100_000_000) : it.price; // remise : gérant / propriétaire seulement
      total += price * qty;
      costTotal += it.cost * qty;
      resolved.push({ id: it.id, name: it.name, qty, price, cost: it.cost });
    }
    const method = PAY_METHODS.includes(e.method) ? e.method : 'Espèces';
    await q.query('INSERT INTO sales (id, channel_id, cashier_id, cashier, total, cost_total, method, note, customer_phone) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)',
      [id, c.id, user.id, user.name, total, costTotal, method, str(e.note, 300), str(e.customerPhone, 30)]);
    for (const r of resolved) {
      await q.query('INSERT INTO sale_lines (sale_id, item_id, name, qty, unit_price, unit_cost) VALUES ($1,$2,$3,$4,$5,$6)', [id, r.id, r.name, r.qty, r.price, r.cost]);
      await applyStock(q, await freshItem(q, r.id), -r.qty, 'vente', `Caisse ${id}`, user.name);
    }
  },

  async 'sale.void'(q, user, p) {
    const s = (await q.query('SELECT * FROM sales WHERE id=$1', [str(p.id, 80)])).rows[0];
    if (!s || s.voided) return;
    await staffChannel(q, s.channel_id, user, MANAGE);
    const lines = (await q.query('SELECT * FROM sale_lines WHERE sale_id=$1', [s.id])).rows;
    for (const l of lines) {
      const it = await freshItem(q, l.item_id);
      if (it) await applyStock(q, it, l.qty, 'retour', `Annulation vente ${s.id}`, user.name);
    }
    await q.query('UPDATE sales SET voided=true WHERE id=$1', [s.id]);
  },

  async 'purchase.create'(q, user, p) {
    const e = p.entity || {};
    const c = await staffChannel(q, e.channelId, user, MANAGE);
    const id = str(e.id, 80);
    if (!id) throw new HttpError(400, 'Achat invalide');
    if ((await q.query('SELECT 1 FROM purchases WHERE id=$1', [id])).rows.length) return;
    const lines = Array.isArray(e.lines) ? e.lines : [];
    if (!lines.length || lines.length > 100) throw new HttpError(400, 'Achat vide');
    const extra = int(e.extraCosts ?? 0, 0, 1_000_000_000);
    const parsed = lines.map((l) => ({ itemId: str(l.itemId, 80), qty: int(l.qty, 1, 1_000_000), unitCost: int(l.unitCost, 0, 100_000_000) }));
    const totalValue = parsed.reduce((a, l) => a + l.qty * l.unitCost, 0);
    const totalQty = parsed.reduce((a, l) => a + l.qty, 0);
    await q.query('INSERT INTO purchases (id, channel_id, supplier, extra_costs, note, created_by) VALUES ($1,$2,$3,$4,$5,$6)', [id, c.id, str(e.supplier, 120), extra, str(e.note, 300), user.name]);
    for (const l of parsed) {
      const it = await freshItem(q, l.itemId);
      if (!it || it.channel_id !== c.id) throw new HttpError(404, 'Produit introuvable');
      const share = totalValue > 0 ? (extra * (l.qty * l.unitCost)) / totalValue : (extra * l.qty) / totalQty; // frais répartis au prorata de la valeur
      const landed = Math.round(l.unitCost + share / l.qty);
      const newCost = it.cost > 0 && it.stock + l.qty > 0 ? Math.round((it.stock * it.cost + l.qty * landed) / (it.stock + l.qty)) : landed; // coût moyen pondéré
      await q.query('UPDATE catalog_items SET cost=$2 WHERE id=$1', [it.id, newCost]);
      await q.query('INSERT INTO purchase_lines (purchase_id, item_id, qty, unit_cost, landed_cost) VALUES ($1,$2,$3,$4,$5)', [id, it.id, l.qty, l.unitCost, landed]);
      await applyStock(q, { ...it, cost: newCost }, l.qty, 'entree', `Achat ${str(e.supplier, 60)}`.trim(), user.name);
    }
  },

  async 'reservation.create'(q, user, p) {
    await expireReservations(q);
    const id = str(p.id, 80);
    if (!id) throw new HttpError(400, 'Réservation invalide');
    if ((await q.query('SELECT 1 FROM reservations WHERE id=$1', [id])).rows.length) return;
    const it = await freshItem(q, str(p.itemId, 80));
    if (!it || !it.active) throw new HttpError(404, 'Produit introuvable');
    const qty = int(p.qty, 1, 999);
    if (it.stock < qty) throw new HttpError(409, 'Stock insuffisant pour cette réservation');
    await q.query(
      `INSERT INTO reservations (id, channel_id, item_id, qty, user_id, name, phone, expires_at) VALUES ($1,$2,$3,$4,$5,$6,$7, now() + ($8 || ' hours')::interval)`,
      [id, it.channel_id, it.id, qty, user.id, str(p.name || user.name, 80), str(p.phone, 30), String(config.reservationHours)],
    );
    await applyStock(q, it, -qty, 'reservation', `Réservation ${id}`, user.name);
    const ch = (await q.query('SELECT owner_id, name FROM channels WHERE id=$1', [it.channel_id])).rows[0];
    if (ch) await notice(q, ch.owner_id, `Réservation : ${it.name}`, `${qty} × par ${user.name}, à retirer sous ${config.reservationHours} h`);
  },

  async 'reservation.status'(q, user, p) {
    await expireReservations(q);
    const r = (await q.query('SELECT * FROM reservations WHERE id=$1', [str(p.id, 80)])).rows[0];
    if (!r) throw new HttpError(404, 'Réservation introuvable');
    const target = str(p.status, 20);
    if (!['ready', 'collected', 'cancelled'].includes(target)) throw new HttpError(400, 'Statut invalide');
    if (r.status === target) return;
    if (!['pending', 'ready'].includes(r.status)) throw new HttpError(409, 'Réservation déjà clôturée');
    const role = await roleIn(q, r.channel_id, user);
    const staff = role && SELL.includes(role);
    if (!(staff || (r.user_id === user.id && target === 'cancelled'))) throw new HttpError(403, 'Action non autorisée');
    const it = await freshItem(q, r.item_id);
    if (target === 'cancelled') {
      if (it) await applyStock(q, it, r.qty, 'retour', `Annulation réservation ${r.id}`, user.name);
    } else if (target === 'collected' && it) {
      const sid = `s_${r.id}`;
      await q.query('INSERT INTO sales (id, channel_id, cashier_id, cashier, total, cost_total, method, note, customer_phone) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT (id) DO NOTHING',
        [sid, r.channel_id, user.id, user.name, it.price * r.qty, it.cost * r.qty, 'Espèces', `Réservation ${r.id}`, r.phone]);
      await q.query('INSERT INTO sale_lines (sale_id, item_id, name, qty, unit_price, unit_cost) VALUES ($1,$2,$3,$4,$5,$6)', [sid, it.id, it.name, r.qty, it.price, it.cost]);
    }
    await q.query('UPDATE reservations SET status=$2 WHERE id=$1', [r.id, target]);
    if (target === 'ready') await notice(q, r.user_id, 'Ta réservation est prête', it ? `${r.qty} × ${it.name}` : '');
  },

  async 'alert.subscribe'(q, user, p) {
    const id = str(p.itemId, 80);
    if (p.value) await q.query('INSERT INTO stock_alerts (item_id, user_id) SELECT id, $2 FROM catalog_items WHERE id=$1 ON CONFLICT DO NOTHING', [id, user.id]);
    else await q.query('DELETE FROM stock_alerts WHERE item_id=$1 AND user_id=$2', [id, user.id]);
  },

  async 'demand.log'(q, user, p) {
    const term = String(p.term ?? '').toLowerCase().trim().slice(0, 60);
    if (term.length < 3) return;
    const id = str(p.channelId, 80);
    if (!(await q.query('SELECT 1 FROM channels WHERE id=$1', [id])).rows.length) return;
    await q.query(
      `INSERT INTO demand_terms (channel_id, term) VALUES ($1,$2)
       ON CONFLICT (channel_id, term) DO UPDATE SET count = demand_terms.count + 1, last_at = now()`,
      [id, term],
    );
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

/** Réservations échues : le stock réservé est restitué. */
export async function expireReservations(q) {
  const rows = (await q.query("SELECT * FROM reservations WHERE status IN ('pending','ready') AND expires_at < now()")).rows;
  for (const r of rows) {
    const it = await freshItem(q, r.item_id);
    if (it) await applyStock(q, it, r.qty, 'retour', `Réservation expirée ${r.id}`, '');
    await q.query("UPDATE reservations SET status='expired' WHERE id=$1", [r.id]);
    await notice(q, r.user_id, 'Réservation expirée', it ? `${r.qty} × ${it.name}` : '');
  }
}
