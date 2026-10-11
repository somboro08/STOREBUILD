const env = process.env;
const prod = env.NODE_ENV === 'production';
const port = Number(env.PORT || 3000);

export const config = {
  prod,
  port,
  dbDriver: env.DB_DRIVER || (env.DATABASE_URL ? 'pg' : 'pglite'),
  databaseUrl: env.DATABASE_URL || '',
  pgliteDir: env.PGLITE_DIR || '',
  jwtSecret: env.JWT_SECRET || (prod ? '' : 'dev-secret-change-me'),
  publicUrl: (env.PUBLIC_URL || `http://localhost:${port}`).replace(/\/$/, ''),
  uploadDir: env.UPLOAD_DIR || './uploads',
  commissionRate: Number(env.COMMISSION_RATE || 0.05),
  minPayout: Number(env.MIN_PAYOUT || 1000),
  countryCode: env.COUNTRY_CODE || '229',
  adminPhones: (env.ADMIN_PHONES || '').split(',').map((s) => s.trim()).filter(Boolean),
  allowSelfPurchase: env.ALLOW_SELF_PURCHASE ? env.ALLOW_SELF_PURCHASE === 'true' : !prod,
  smsProvider: env.SMS_PROVIDER || 'console',
  smsWebhookUrl: env.SMS_WEBHOOK_URL || '',
  smsWebhookToken: env.SMS_WEBHOOK_TOKEN || '',
  otpFixed: prod ? '' : env.OTP_FIXED || '',
  paymentProvider: env.PAYMENT_PROVIDER || 'mock',
  allowMockPayments: env.ALLOW_MOCK_PAYMENTS === 'true' || !prod,
  webhookSecret: env.WEBHOOK_SECRET || '',
  paymentPollMs: Number(env.PAYMENT_POLL_MS || 3000),
  androidPackage: env.ANDROID_PACKAGE || 'store.whatstore.whatstore',
  androidSha256: env.ANDROID_SHA256 || '',
  appleAppId: env.APPLE_APP_ID || '',
};

if (prod && !config.jwtSecret) throw new Error('JWT_SECRET est obligatoire en production');
if (prod && config.paymentProvider === 'mock' && !config.allowMockPayments) {
  throw new Error('PAYMENT_PROVIDER=mock interdit en production (ou ALLOW_MOCK_PAYMENTS=true)');
}
