import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from './config.js';
import { db } from './db.js';
import { sendSms } from './sms.js';
import { HttpError, normalizePhone } from './util.js';

const hashCode = (phone, code) => crypto.createHash('sha256').update(`${phone}:${code}:${config.jwtSecret}`).digest('hex');

export const isAdminPhone = (phone) => config.adminPhones.map(normalizePhone).includes(phone);

export async function requestCode(rawPhone) {
  const phone = normalizePhone(rawPhone);
  if (phone.length < 8) throw new HttpError(400, 'Numéro invalide');
  const { rows } = await db.query('SELECT created_at FROM otps WHERE phone=$1', [phone]);
  if (!config.otpFixed && rows[0] && Date.now() - new Date(rows[0].created_at).getTime() < 30000) {
    throw new HttpError(429, 'Patiente quelques secondes avant de redemander un code');
  }
  const code = config.otpFixed || String(crypto.randomInt(100000, 1000000));
  await db.query(
    `INSERT INTO otps (phone, code_hash, expires_at, attempts, created_at)
     VALUES ($1, $2, now() + interval '5 minutes', 0, now())
     ON CONFLICT (phone) DO UPDATE SET code_hash=$2, expires_at=now() + interval '5 minutes', attempts=0, created_at=now()`,
    [phone, hashCode(phone, code)],
  );
  await sendSms(phone, `Whatstore : ton code de vérification est ${code}`);
}

export async function checkCode(phone, code) {
  const o = (await db.query('SELECT * FROM otps WHERE phone=$1', [phone])).rows[0];
  if (!o || new Date(o.expires_at) < new Date()) throw new HttpError(400, 'Code expiré, redemande-en un');
  if (o.attempts >= 5) throw new HttpError(429, "Trop d'essais, redemande un code");
  if (o.code_hash !== hashCode(phone, String(code))) {
    await db.query('UPDATE otps SET attempts=attempts+1 WHERE phone=$1', [phone]);
    throw new HttpError(400, 'Code incorrect');
  }
  await db.query('DELETE FROM otps WHERE phone=$1', [phone]);
}

export const signToken = (userId) => jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: '60d' });

export const publicUser = (u) => ({ name: u.name, phone: u.phone_display || `+${u.phone}`, isAdmin: isAdminPhone(u.phone) });

export async function verify(rawPhone, code, name) {
  const phone = normalizePhone(rawPhone);
  await checkCode(phone, code);
  let u = (await db.query('SELECT * FROM users WHERE phone=$1', [phone])).rows[0];
  const clean = String(name || '').trim().slice(0, 80);
  if (!u) {
    const id = `usr_${crypto.randomUUID()}`;
    await db.query('INSERT INTO users (id, phone, phone_display, name) VALUES ($1,$2,$3,$4)', [id, phone, String(rawPhone).trim(), clean]);
    u = (await db.query('SELECT * FROM users WHERE id=$1', [id])).rows[0];
  } else if (!u.name && clean) {
    await db.query('UPDATE users SET name=$2 WHERE id=$1', [u.id, clean]);
    u.name = clean;
  }
  return { token: signToken(u.id), user: publicUser(u) };
}

/** Middleware : charge req.user (JWT Bearer) ou répond 401. */
export async function requireAuth(req, res, next) {
  try {
    const h = req.headers.authorization || '';
    if (!h.startsWith('Bearer ')) throw new HttpError(401, 'Connexion requise');
    let payload;
    try {
      payload = jwt.verify(h.slice(7), config.jwtSecret);
    } catch {
      throw new HttpError(401, 'Session expirée');
    }
    const u = (await db.query('SELECT * FROM users WHERE id=$1 AND deleted_at IS NULL', [payload.sub])).rows[0];
    if (!u) throw new HttpError(401, 'Compte introuvable');
    req.user = { id: u.id, name: u.name, phone: u.phone, phoneDisplay: u.phone_display, isAdmin: isAdminPhone(u.phone) };
    next();
  } catch (e) {
    next(e);
  }
}
