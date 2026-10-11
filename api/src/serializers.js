import { iso, num } from './util.js';

/** Formats JSON identiques à toJson() côté Flutter (frontend/lib/data.dart et frontend/lib/models.dart). */
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
    logo: null, logoUrl: c.logo_url, posts,
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
