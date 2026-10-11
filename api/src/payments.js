import { config } from './config.js';
import { HttpError, sleep } from './util.js';

/**
 * Adaptateurs de paiement mobile money.
 * Un adaptateur implémente :
 *   charge({ provider, phone, amount, reference }) -> { ok, pending?, message?, externalId? }
 *   status(reference, externalId)                  -> { status: 'pending' | 'succeeded' | 'failed', message? }
 *   refund({ reference, externalId, amount, phone, provider }) -> { ok, message? }
 * Pour un vrai prestataire (FedaPay, Kkiapay, API MTN MoMo...), écris une classe sur ce modèle et
 * ajoute-la dans getProvider(). Le mobile money est asynchrone : charge() peut renvoyer { pending: true }
 * puis status() est interrogé (ou le webhook /webhooks/payments confirme).
 */
class MockProvider {
  async charge({ phone, reference }) {
    await sleep(20);
    return phone.replace(/\D/g, '').length >= 8 ? { ok: true, externalId: `mock_${reference}` } : { ok: false, message: 'Numéro invalide' };
  }
  async status() {
    return { status: 'succeeded' };
  }
  async refund() {
    return { ok: true };
  }
}

let provider;
export function getProvider() {
  if (provider) return provider;
  switch (config.paymentProvider) {
    case 'mock':
      return (provider = new MockProvider());
    default:
      throw new Error(`PAYMENT_PROVIDER inconnu : ${config.paymentProvider} (voir src/payments.js)`);
  }
}
export const setProvider = (p) => (provider = p); // tests

const NETWORKS = ['MTN MoMo', 'Moov Money', 'Celtiis Cash'];

/** Débite le client. q = { query }. Idempotent sur `reference`. */
export async function chargePayment(q, userId, { provider: network, phone, amount, reference }) {
  if (!NETWORKS.includes(network)) throw new HttpError(400, 'Moyen de paiement inconnu');
  if (!Number.isInteger(amount) || amount <= 0) throw new HttpError(400, 'Montant invalide');
  if (typeof reference !== 'string' || reference.length < 3 || reference.length > 64) throw new HttpError(400, 'Référence invalide');
  const ex = (await q.query('SELECT * FROM payments WHERE reference=$1', [reference])).rows[0];
  if (ex) {
    if (ex.user_id !== userId) throw new HttpError(409, 'Référence déjà utilisée');
    if (ex.status === 'succeeded') return { ok: true };
    if (ex.amount !== amount) throw new HttpError(409, 'Montant différent de la tentative précédente');
  } else {
    await q.query('INSERT INTO payments (reference,user_id,provider,phone,amount,status) VALUES ($1,$2,$3,$4,$5,$6)', [reference, userId, network, String(phone || ''), amount, 'pending']);
  }
  const prov = getProvider();
  const r = await prov.charge({ provider: network, phone: String(phone || ''), amount, reference });
  let status = r.ok && !r.pending ? 'succeeded' : r.pending ? 'pending' : 'failed';
  let message = r.message;
  for (let i = 0; i < 30 && status === 'pending'; i++) {
    await sleep(config.paymentPollMs);
    const s = await prov.status(reference, r.externalId);
    status = s.status;
    message = s.message || message;
  }
  if (status === 'pending') message = 'Paiement non confirmé : valide la demande sur ton téléphone puis réessaie';
  await q.query('UPDATE payments SET status=$2, external_id=$3 WHERE reference=$1', [reference, status, r.externalId || null]);
  return { ok: status === 'succeeded', message: status === 'succeeded' ? undefined : message || 'Paiement refusé' };
}

/** Rembourse un paiement (idempotent). */
export async function refundByReference(q, reference) {
  const p = (await q.query('SELECT * FROM payments WHERE reference=$1', [reference])).rows[0];
  if (!p) return { ok: false, message: 'Paiement introuvable' };
  if (p.refunded) return { ok: true };
  if (p.status !== 'succeeded') return { ok: false, message: 'Paiement non abouti' };
  const r = await getProvider().refund({ reference, externalId: p.external_id, amount: p.amount, phone: p.phone, provider: p.provider });
  if (r.ok) await q.query('UPDATE payments SET refunded=true WHERE reference=$1', [reference]);
  return r;
}
