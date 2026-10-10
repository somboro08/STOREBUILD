# Whatstore (Flutter)

Site : https://whatstore.store

## Installation
1. `flutter create . --org store.whatstore --project-name whatstore` (génère android/ios, ne touche pas à lib/ ni assets/)
   -> identifiant d'app : `store.whatstore.whatstore` (change `--org` si tu préfères)
2. `flutter pub get`
3. Icône d'app et écran de démarrage : `dart run flutter_launcher_icons` puis `dart run flutter_native_splash:create`
4. iOS uniquement : ajouter `NSPhotoLibraryUsageDescription` et `NSCameraUsageDescription` dans `ios/Runner/Info.plist` (image_picker).
5. `flutter run`

## Réglages avant la mise en ligne
- `lib/brand.dart` -> `demoData = false` retire toutes les données de démo (boutiques et produits fictifs)
- Mode clair/sombre/automatique : Profil > Apparence (choix mémorisé). Palette dans `lib/theme.dart` (classe `C`, une valeur sombre et une claire par couleur)
- Première ouverture : écran de présentation (3 écrans), puis connexion ; la session et les préférences sont mémorisées (shared_preferences)

## Identité
- `lib/brand.dart` : nom, domaine, slogan (utilisés dans l'app et les liens de partage)
- `lib/widgets/brand_logo.dart` : logo dessiné en code ; `assets/brand/` : icon.png, icon_foreground.png, logo.svg
- `lib/theme.dart` : couleurs (vert WhatsApp pour l'instant, à remplacer par ta couleur de marque)

## Écrans
Présentation -> Connexion -> Coque (Boutiques, Explorer, Commandes, Profil)
- Boutiques : suivies (épinglables), notifications -> Fil (filtre catégories, appui long, annonces, photos multiples, vidéos) -> Infos / Avis / Médias / Visionneuse -> Détail produit (options, stock, contact)
- Explorer : toutes les boutiques, Suivre/Suivie, ouverture d'un lien ; Recherche (sans accents, catégorie, prix, tri, historique)
- Panier -> Paiement mobile money (retrait ou livraison + adresses) -> Suivi de commande -> Avis
- Profil : boutiques, tableau de bord vendeur (produits, commandes, revenus, retraits), adresses, favoris, notifications, apparence, légal, changement de numéro, suppression du compte, administration

## Mode local / mode API
L'app fonctionne entièrement hors-ligne (sauvegarde sur le téléphone). Pour la brancher à l'API : `Brand.apiBaseUrl` dans `lib/brand.dart`. Voir `docs/API_CONTRACT.md`, `docs/PLATFORM_SETUP.md` (permissions, liens profonds, signature), `docs/STORE_LISTING.md` (fiches des stores).
Dans le code : `lib/services/` (interfaces + implémentations locales et API), `lib/state.dart` (état, sauvegarde, file de synchronisation).

## Tests
`flutter test` (logique : accents, téléphones, commissions, stock, notes, sérialisation).

## Points à valider avant la publication
- Textes légaux (lib/screens/legal_screen.dart) à faire relire par un juriste
- `Brand.demoData = false`, `Brand.adminPhones`, `Brand.supportEmail`
- Remplacer MockPaymentService par un vrai prestataire (côté API)
- Tout le code a été écrit sans compilateur : lance `flutter run` et corrige les éventuelles erreurs
