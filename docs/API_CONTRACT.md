# Contrat API Whatstore

L'app tourne 100 % en local tant que `Brand.apiBaseUrl` (`frontend/lib/brand.dart`) est vide.
Pour passer en mode API : `static const apiBaseUrl = 'https://api.whatstore.store';` — rien d'autre à changer.

Principe : **offline-first**. Chaque action est appliquée localement puis ajoutée à une file d'opérations (`SyncOp`).
Quand le réseau est là, l'app envoie les opérations dans l'ordre (`POST /sync/ops`), puis récupère l'état serveur (`GET /sync/snapshot`).
Les identifiants (boutiques, produits...) sont générés par le client (texte) : les opérations sont donc **idempotentes** (l'opération a un `id` unique).

Authentification : `Authorization: Bearer <token>` (JWT renvoyé par `/auth/verify`).

## Auth
| Route | Corps | Réponse |
|---|---|---|
| POST /auth/request-code | `{phone}` | `{ok:true}` (SMS envoyé) |
| POST /auth/verify | `{phone, code, name}` | `{token, user:{name, phone}}` |
| POST /me/phone | `{phone, code}` (après /auth/request-code sur le nouveau numéro) | `{user:{name, phone}}` |
| GET /me | | `{user:{name, phone, isAdmin}}` |
| DELETE /me | | `{ok:true}` (supprime/anonymise le compte) |

## Médias
`POST /media` (multipart : `file`, `kind` = post|logo|video) -> `{url}`.
L'app envoie les images/vidéos avant l'opération `post.*` / `store.*` et met les URLs dans `imageUrl`, `extraUrls`, `videoUrl`, `logoUrl`.

## Paiements
`POST /payments` `{provider, phone, amount, reference}` -> `{ok, message}`
`POST /payments/refund` `{provider, phone, amount, reference}` -> `{ok, message}`
Le serveur vérifie, à la création de commande, qu'un paiement réussi existe pour `reference` avec le bon montant.

## Synchronisation
`POST /sync/ops` : corps = une opération `{id, type, payload, date}` -> `{ok:true}`.
Codes : 2xx = pris en compte ; 4xx (sauf 401/408/429) = opération invalide, abandonnée ; 5xx / réseau = l'app réessaie.

| type | payload |
|---|---|
| store.create / store.update | `{entity: Channel (sans posts)}` |
| store.follow | `{channelId, followed}` |
| store.verify (admin) | `{channelId, verified}` |
| post.create / post.update | `{channelId, postId, entity: Post}` |
| post.delete | `{channelId, postId}` |
| post.react | `{channelId, postId, emoji}` (emoji null = retirer) |
| favorite.set | `{postId, value}` |
| order.create | `{entity: Order}` (le serveur recalcule prix, frais, commission) |
| order.status | `{ref, status, refunded}` (status = index : 0 payée, 1 confirmée, 2 prête, 3 livrée, 4 annulée) |
| review.create | `{entity: Review}` |
| report.create | `{channelId, reason}` |
| payout.request | `{entity: Payout}` |
| address.save / address.delete | `{entity: Address}` / `{id}` |
| account.update | `{name, phone}` (le téléphone ne change que via /me/phone) |

Les formats `Channel`, `Post`, `Order`... sont ceux de `toJson()` dans `frontend/lib/data.dart` et `frontend/lib/models.dart`.

## Snapshot
`GET /sync/snapshot` renvoie le même format que le fichier local : `channels` (avec `posts`), `orders`, `reviews`, `addresses`, `payouts`, `notices`, `reports` (admin), `favorites`. Les clés absentes ne modifient pas l'état local.
Les drapeaux propres à l'utilisateur (`mine`, `followed`) sont calculés par le serveur.

## Routes supplémentaires
- `GET /channels/:id`, `GET /posts/:id` : lecture publique (résolution des liens profonds quand la boutique n'est pas encore dans l'app).
- `GET /s/:id`, `GET /p/:id` : pages web d'aperçu (Open Graph) des liens partagés ; `/.well-known/assetlinks.json` et `/.well-known/apple-app-site-association` pour les liens universels.
- Opération `device.register` `{token, platform}` : enregistrement d'un appareil pour les notifications push (envoi à brancher côté serveur, voir `src/push.js`).

L'implémentation de référence se trouve dans `api/` (testée par `npm test`).
