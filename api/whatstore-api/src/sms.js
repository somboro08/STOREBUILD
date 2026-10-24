import { config } from './config.js';

/** Envoie un SMS. "console" affiche le message (dev) ; "webhook" appelle ta passerelle SMS. */
export async function sendSms(phone, message) {
  if (config.smsProvider === 'webhook') {
    if (!config.smsWebhookUrl) throw new Error('SMS_WEBHOOK_URL manquant');
    const res = await fetch(config.smsWebhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(config.smsWebhookToken ? { Authorization: `Bearer ${config.smsWebhookToken}` } : {}) },
      body: JSON.stringify({ to: `+${phone}`, message }),
    });
    if (!res.ok) throw new Error(`Passerelle SMS : ${res.status}`);
    return;
  }
  if (!config.otpFixed) console.log(`[SMS → +${phone}] ${message}`);
}
