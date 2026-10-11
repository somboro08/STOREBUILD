# Whatstore

Application de commerce mobile inspirée des habitudes de messagerie. Le dépôt sépare maintenant l’application Flutter et son API Node.js.

## Structure

- `frontend/` : application Flutter Android, écrans, logique locale et configuration de compilation.
- `api/` : API Node.js/Express, schéma PostgreSQL, conteneurs et tests d’intégration.
- `docs/` : contrat API, configuration des liens et fiche de présentation des stores.
- `.github/workflows/` : compilation de l’APK avec GitHub Actions.

## Démarrer le front

Depuis `frontend/` :

```bash
flutter pub get
flutter run
```

Pour générer l’APK localement : `flutter build apk --release`. Le fichier est produit dans `frontend/build/app/outputs/flutter-apk/app-release.apk`.

## Démarrer l’API

Depuis `api/`, consulter [api/README.md](api/README.md) pour les commandes de développement et la configuration serveur.

Le workflow GitHub compile automatiquement le front sur chaque push vers `main`. L’APK se télécharge depuis l’artefact **martistore-release-apk** dans l’onglet Actions.
