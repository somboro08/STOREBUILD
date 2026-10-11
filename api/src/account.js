import { tx } from './db.js';

/** Suppression du compte : données personnelles effacées, historique comptable anonymisé. */
export async function deleteAccount(userId) {
  await tx(async (q) => {
    await q.query('DELETE FROM channels WHERE owner_id=$1', [userId]); // cascade : publications, abonnements
    await q.query('DELETE FROM follows WHERE user_id=$1', [userId]);
    await q.query('DELETE FROM favorites WHERE user_id=$1', [userId]);
    await q.query('DELETE FROM post_reactions WHERE user_id=$1', [userId]);
    await q.query('DELETE FROM addresses WHERE user_id=$1', [userId]);
    await q.query('DELETE FROM device_tokens WHERE user_id=$1', [userId]);
    await q.query('DELETE FROM notices WHERE user_id=$1', [userId]);
    await q.query('DELETE FROM reviews WHERE author_id=$1', [userId]);
    await q.query("UPDATE orders SET buyer_name='', address='', phone='' WHERE buyer_id=$1", [userId]);
    await q.query("UPDATE users SET name='', phone='deleted:' || id, phone_display='', deleted_at=now() WHERE id=$1", [userId]);
  });
}
