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
Connexion (téléphone + code) -> Coque (Actus, Explorer, Commandes, Profil)
- Actus : stores suivis (épinglables) -> Fil du store (filtre catégories, appui long sur une publication) -> Infos / Médias et liens / Visionneuse -> Détail produit
- Explorer : tous les stores, Suivre/Suivie ; Recherche produits (catégorie, prix, tri)
- Panier -> Paiement mobile money -> Confirmation -> Suivi de commande
- Profil : mes stores (tableau de bord vendeur : produits, commandes reçues, infos), créer/modifier un store, favoris, notifications, déconnexion

## À brancher sur ton backend
- `lib/state.dart` : données/état en mémoire -> API Node.js/PostgreSQL
- `lib/screens/login_screen.dart` : le code OTP est simulé (tout code à 6 chiffres passe)
- `lib/payment.dart` : `MockPaymentService` simule le paiement -> appel réel (FedaPay, Kkiapay, ton orchestrateur)
- Images publiées gardées en mémoire (bytes) -> upload vers ton stockage puis `Image.network`
- Partage = copie du lien `https://whatstore.store/...` ; enregistrement d'image = message placeholder
- Statut de commande : un seul statut par commande, même si elle contient plusieurs stores
- Données de démo (MARTISTORE OFFICIEL, TechShop, Mode Africaine) dans `lib/data.dart` : à retirer avant la mise en ligne
