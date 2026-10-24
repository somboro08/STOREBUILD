import { iso, num } from './util.js';

/** Formats JSON identiques à toJson() côté Flutter (lib/data.dart et lib/models.dart). */
export function postJson(p, reactions = [], myEmoji = null) {
  return {
    id: p.id, type: p.type, time: p.time, text: p.text || '', title: p.title, quote: p.quote,
    category: p.category, price: num(p.price), stock: num(p.stock), variants: p.variants || [],
    reactions: reactions.map((r) => r.emoji).slice(0, 6),
    rc: reactions.reduce((a, r) => a + r.c, 0), fw: p.forwards || 0,
    color: Number(p.color), bold: !!p.bold, sold: !!p.sold, mine: myEmoji,
    img: null, extra: [], imageUrl: p.image_url, extraUrls: p.extra_urls || [], videoUrl: p.video_url, video: null,
  };
}

export function channelJson(c, user, posts) {
  const last = posts[posts.length - 1];
  return {
    id: c.id, name: c.name, description: c.description, category: c.category, zone: c.zone, phone: c.phone,
    preview: last ? last.title || last.text || 'Nouvelle publication' : '', time: last ? last.time : '',
    created: c.created, followers: Number(c.followers || 0), unread: 0, color: Number(c.color),
    mine: !!user && c.owner_id === user.id, followed: !!c.followed, muted: false, storageMo: 0,
    verified: !!c.verified, delivers: !!c.delivers, deliveryFee: c.delivery_fee, ownerPhone: null,
    logo: null, logoUrl: c.logo_url, role: c.member_role || null, posts,
  };
}

export function orderJson(o, lines, reviewed) {
  return {
    ref: o.ref, provider: o.provider, phone: o.phone, buyer: o.buyer_name, address: o.address,
    lines: lines.map((l) => ({ c: l.channel_id, p: l.post_id, q: l.qty, v: l.variant, t: l.title, pr: l.unit_price })),
    delivery: !!o.delivery, fees: o.fees || {}, date: iso(o.created_at), status: o.status, refunded: !!o.refunded,
    reviewed,
  };
}

export const reviewJson = (r) => ({ id: r.id, channelId: r.channel_id, postId: r.post_id, author: r.author, rating: r.rating, text: r.text, date: iso(r.created_at) });
export const addressJson = (a) => ({ id: a.id, label: a.label, text: a.text });
export const payoutJson = (p) => ({ id: p.id, channelId: p.channel_id, amount: p.amount, phone: p.phone, date: iso(p.created_at), status: p.status });
export const noticeJson = (n) => ({ id: n.id, title: n.title, body: n.body, date: iso(n.created_at), read: !!n.read });
export const reportJson = (r) => ({ channelId: r.channel_id, reason: r.reason, by: r.reporter_name, date: iso(r.created_at) });

/** Produit du catalogue. role : owner | manager | cashier | stock | null (client). Le client voit un stock arrondi et pas le prix d'achat. */
export function catalogItemJson(i, role) {
  const low = Number(i.low_stock);
  const stock = Number(i.stock);
  const staff = !!role;
  const shown = staff ? stock : stock <= 0 ? 0 : stock <= low ? stock : low + 1;
  return {
    id: i.id, channelId: i.channel_id, groupId: i.group_id, code: i.code, name: i.name, description: i.description, usage: i.usage,
    location: i.location, unit: i.unit, variant: i.variant, category: i.category, postId: i.post_id,
    barcodes: i.barcodes || [], imageUrls: i.image_urls || [], details: i.details || [], price: i.price,
    cost: role === 'owner' || role === 'manager' ? i.cost : 0, stock: shown, lowStock: low, active: !!i.active, imgs: [],
  };
}
export const groupJson = (g) => ({ id: g.id, channelId: g.channel_id, parentId: g.parent_id, name: g.name });
export const movementJson = (m) => ({ id: m.id, itemId: m.item_id, channelId: m.channel_id, delta: m.delta, kind: m.kind, note: m.note, by: m.by_name, after: m.balance_after, date: iso(m.created_at) });

export const saleJson = (s, lines) => ({
  id: s.id, channelId: s.channel_id, cashier: s.cashier, method: s.method, note: s.note, customerPhone: s.customer_phone, total: s.total,
  costTotal: s.cost_total, voided: !!s.voided, date: iso(s.created_at),
  lines: lines.map((l) => ({ itemId: l.item_id, name: l.name, qty: l.qty, unitPrice: l.unit_price, unitCost: l.unit_cost })),
});
export const purchaseJson = (p, lines) => ({
  id: p.id, channelId: p.channel_id, supplier: p.supplier, note: p.note, extraCosts: p.extra_costs, date: iso(p.created_at),
  lines: lines.map((l) => ({ itemId: l.item_id, qty: l.qty, unitCost: l.unit_cost, landed: l.landed_cost })),
});
export const reservationJson = (r, userId = '') => ({
  id: r.id, channelId: r.channel_id, itemId: r.item_id, itemName: r.item_name || '', qty: r.qty, name: r.name, phone: r.phone, status: r.status,
  date: iso(r.created_at), expires: iso(r.expires_at), mine: r.user_id === userId,
});
export const memberJson = (m) => ({ channelId: m.channel_id, phone: m.phone, name: m.name, role: m.role });
export const demandJson = (d) => ({ channelId: d.channel_id, term: d.term, count: d.count, last: iso(d.last_at) });
