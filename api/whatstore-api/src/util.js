import { config } from './config.js';

export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Même logique que normalizePhone() côté Flutter : chiffres + indicatif pays. */
export function normalizePhone(raw) {
  const s = String(raw ?? '').trim();
  const d = s.replace(/\D/g, '');
  if (!d) return '';
  if (s.startsWith('+')) return d;
  if (d.startsWith('00')) return d.slice(2);
  if (d.startsWith(config.countryCode) && d.length > 10) return d;
  return config.countryCode + d;
}

export function str(v, max = 500) {
  const s = v == null ? '' : String(v);
  if (s.length > max) throw new HttpError(400, `Texte trop long (max ${max})`);
  return s;
}

export function int(v, min, max) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new HttpError(400, `Valeur invalide (${min}–${max})`);
  return n;
}

export function url(v) {
  if (v == null || v === '') return null;
  const s = String(v);
  if (s.length > 600 || !/^https?:\/\//i.test(s)) throw new HttpError(400, 'URL invalide');
  return s;
}

export const iso = (d) => (d instanceof Date ? d : new Date(d)).toISOString();
export const num = (v) => (v == null ? null : Number(v));
