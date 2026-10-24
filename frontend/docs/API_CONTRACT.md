# Contrat API Whatstore

L'app tourne 100 % en local tant que `Brand.apiBaseUrl` (lib/brand.dart) est vide.
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

Les formats `Channel`, `Post`, `Order`... sont ceux de `toJson()` dans `lib/data.dart` et `lib/models.dart`.

### Catalogue physique et stock
| type | payload |
|---|---|
| catalog.group.save | `{entity: {id, channelId, parentId?, name}}` (sous-catalogue) |
| catalog.group.delete | `{id, channelId}` (produits et sous-dossiers remontent d'un niveau) |
| catalog.codes.create | `{channelId, codes: [...]}` (étiquettes vierges imprimées) |
| catalog.item.save | `{entity: CatalogItem}` (code unique par boutique, codes-barres uniques par boutique ; le `stock` envoyé est ignoré) |
| catalog.item.delete | `{id, channelId}` (archivage) |
| stock.move | `{id, channelId, itemId, delta, kind, note}` ; kind : entree, vente, perte, retour, inventaire, vente_en_ligne, initial |

### Équipe, caisse, achats, réservations (phase 2 et 3)
| type | payload | rôles autorisés |
|---|---|---|
| team.invite | `{channelId, phone, name, role}` (role : manager, cashier, stock) | propriétaire |
| team.remove | `{channelId, phone}` | propriétaire |
| sale.create | `{entity: Sale}` (prix recalculés par le serveur ; remise réservée gérant / propriétaire) | propriétaire, gérant, caissier |
| sale.void | `{id, channelId}` (stock restitué) | propriétaire, gérant |
| purchase.create | `{entity: Purchase}` (frais répartis, coût moyen pondéré) | propriétaire, gérant |
| reservation.create | `{id, itemId, qty, name, phone}` (retire le stock, expire après `RESERVATION_HOURS`) | tout utilisateur connecté |
| reservation.status | `{id, status}` : ready, collected (crée une vente), cancelled | personnel de vente ; le client peut annuler la sienne |
| alert.subscribe | `{itemId, value}` (notification au retour en stock) | tout utilisateur connecté |
| demand.log | `{channelId, term}` (recherche sans résultat) | tout utilisateur connecté |

Droits par rôle : magasinier = catalogue et stock (pas de prix d'achat) ; caissier = caisse, consultation, réservations ; gérant = tout sauf équipe et retraits. `GET /registry/:barcode` renvoie une suggestion de fiche issue des autres boutiques.
Le snapshot ajoute `sales`, `purchases`, `reservations`, `members`, `demand`, `alerts` et le champ `role` de chaque boutique.

Le stock ne change **que** par `stock.move` (jamais par écrasement), ce qui rend la synchronisation hors-ligne sûre.
Un produit lié à une publication en ligne (`postId`) partage son stock avec elle, dans les deux sens : une commande en ligne ou son annulation écrit un mouvement `vente_en_ligne` / `retour` dans le catalogue ; un mouvement en magasin met à jour la publication.

Routes de consultation : `GET /catalog/:channelId/:code` (code court ou code-barres ; public : prix d'achat masqué et stock arrondi à disponible / limité / rupture ; propriétaire : tout) et `GET /q/:channelId/:code` (page web ouverte quand un client scanne l'étiquette avec l'appareil photo du téléphone). Le contenu des QR est `https://whatstore.store/q/<boutique>/<code>`.

## Snapshot
`GET /sync/snapshot` renvoie le même format que le fichier local : `channels` (avec `posts`), `orders`, `reviews`, `addresses`, `payouts`, `notices`, `groups`, `items`, `movements` (propriétaire), `blankCodes` (propriétaire), `reports` (admin), `favorites`. Les clés absentes ne modifient pas l'état local.
Les drapeaux propres à l'utilisateur (`mine`, `followed`) sont calculés par le serveur.

## Routes supplémentaires
- `GET /channels/:id`, `GET /posts/:id` : lecture publique (résolution des liens profonds quand la boutique n'est pas encore dans l'app).
- `GET /s/:id`, `GET /p/:id` : pages web d'aperçu (Open Graph) des liens partagés ; `/.well-known/assetlinks.json` et `/.well-known/apple-app-site-association` pour les liens universels.
- Opération `device.register` `{token, platform}` : enregistrement d'un appareil pour les notifications push (envoi à brancher côté serveur, voir `src/push.js`).

L'implémentation de référence se trouve dans `whatstore-api/` (testée par `npm test`).
