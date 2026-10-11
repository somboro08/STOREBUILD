# Whatstore API

API Node.js (Express) + PostgreSQL pour l'application Flutter Whatstore. Contrat complet : `../docs/API_CONTRACT.md`.

## Démarrage rapide (sans installer PostgreSQL)
```bash
npm install
cp .env.example .env      # puis lis les commentaires
npm run dev               # http://localhost:3000 — base PGlite (Postgres embarqué) dans ./data
npm test                  # 4 tests d'intégration (parcours complet)
```
Dans l'app Flutter : `../frontend/lib/brand.dart` -> `apiBaseUrl = 'http://<ip-de-ta-machine>:3000'` (et `demoData = false`).
En dev, `OTP_FIXED=123456` : le code SMS est toujours 123456.

## Avec PostgreSQL
```bash
docker compose up --build            # API + PostgreSQL
# ou : DATABASE_URL=postgres://user:pass@host:5432/db npm start   (le schéma est appliqué au démarrage)
```

## Routes
| | |
|---|---|
| POST /auth/request-code, /auth/verify | connexion par téléphone + code (JWT 60 jours) |
| GET /me · POST /me/phone · DELETE /me | profil, changement de numéro vérifié, suppression du compte |
| POST /media | envoi image / vidéo (multipart `file`) -> `{url}` |
| POST /payments · /payments/refund | paiement et remboursement mobile money (adaptateurs dans `src/payments.js`) |
| POST /webhooks/payments | confirmation asynchrone du prestataire (signature HMAC `x-signature`) |
| POST /sync/ops · GET /sync/snapshot | synchronisation offline-first de l'app |
| GET /channels/:id · /posts/:id | lecture publique (liens profonds) |
| GET /s/:id · /p/:id | pages d'aperçu des liens partagés |
| GET /.well-known/assetlinks.json · apple-app-site-association | liens universels Android / iOS |

## Ce que le serveur garantit (il ne fait pas confiance à l'app)
- Prix, frais de livraison, stock et commission **recalculés côté serveur** ; une commande exige un paiement réussi du même montant.
- Opérations **idempotentes** (rejouer une opération ne duplique rien) et atomiques.
- Seul le propriétaire modifie sa boutique ; seul le vendeur fait avancer le statut (dans l'ordre) ; annulation = remboursement + stock restitué.
- Avis uniquement après livraison, une fois par commande ; retrait limité au solde (ventes livrées - commission - retraits).
- Vérification de boutique réservée aux numéros de `ADMIN_PHONES`.
- Code SMS haché, expirant (5 min), 5 essais max ; limitation de débit ; en production : `JWT_SECRET` obligatoire et faux paiement interdit.

## À brancher avant la mise en production
1. **SMS** : `SMS_PROVIDER=webhook` + `SMS_WEBHOOK_URL` (ta passerelle SMS) — le mode `console` ne fait qu'afficher le code.
2. **Paiement réel** : écrire l'adaptateur de ton prestataire (FedaPay, Kkiapay, API MTN MoMo...) dans `src/payments.js` (`charge`, `status`, `refund`) puis `PAYMENT_PROVIDER=<nom>`. Aucun prestataire réel n'est branché dans ce code : seul le faux paiement l'est.
3. **Fichiers** : `/media` écrit sur le disque ; en production, utiliser un stockage objet (S3 / R2) ou un volume persistant.
4. **Push** : enregistrement des appareils prêt (`device.register`), envoi à brancher sur Firebase Cloud Messaging dans `src/push.js`.
5. HTTPS (reverse proxy), `PUBLIC_URL`, sauvegardes PostgreSQL, `ANDROID_SHA256` / `APPLE_APP_ID` pour les liens universels.
