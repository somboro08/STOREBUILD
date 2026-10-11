import { db } from './db.js';

/**
 * Notifications push : point d'extension. Les appareils s'enregistrent via l'opération `device.register`
 * (table device_tokens). Branche ici Firebase Cloud Messaging (firebase-admin) pour envoyer réellement.
 */
export async function pushToUser(userId, title, body) {
  const { rows } = await db.query('SELECT token, platform FROM device_tokens WHERE user_id=$1', [userId]);
  for (const r of rows) {
    // TODO FCM : admin.messaging().send({ token: r.token, notification: { title, body } })
    void r;
    void title;
    void body;
  }
}
