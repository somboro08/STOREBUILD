# MartiStore (Flutter)

## Build APK avec GitHub Actions

Le workflow `.github/workflows/build-apk.yml` compile l'APK release a chaque push ou pull request vers `main`. Il peut aussi etre lance manuellement depuis l'onglet **Actions**.

Pour recuperer l'APK, ouvre l'execution terminee du workflow sur GitHub et telecharge l'artefact **martistore-release-apk**. Le fichier s'appelle `app-release.apk`.

Pour compiler localement : `flutter pub get` puis `flutter build apk --release`. Le fichier sera dans `build/app/outputs/flutter-apk/app-release.apk`.

1. Dans ce dossier : `flutter create . --org com.martistore` (génère android/ios, ne touche pas à lib/)
2. `flutter pub get`
3. iOS uniquement : ajouter dans `ios/Runner/Info.plist` les clés `NSPhotoLibraryUsageDescription` et `NSCameraUsageDescription` (image_picker).
4. `flutter run`

## Fonctionnalités
- Accueil (stores suivis) / Explorer (tous les stores, Suivre/Suivie en un tap)
- Créer son store ; publier un produit (image + catégorie obligatoires)
- Fil du store filtrable par catégorie ; recherche globale avec filtres (catégorie, prix, tri)
- Panier, paiement mobile money (MTN MoMo, Moov Money, Celtiis Cash)

## À brancher sur ton backend
- `lib/state.dart` : données/état en mémoire -> API Node.js/PostgreSQL
- `lib/payment.dart` : `MockPaymentService` simule le paiement -> remplacer par l'appel réel (FedaPay, Kkiapay, ton orchestrateur)
- Les images publiées sont gardées en mémoire (bytes) -> upload vers ton stockage puis `Image.network`
