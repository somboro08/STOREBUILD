# Configuration Android / iOS

Les commandes Flutter se lancent depuis `frontend/`. Ajoute ensuite les réglages suivants pour les liens et les permissions :

## Android — `frontend/android/app/src/main/AndroidManifest.xml`
Dans `<manifest>` (avant `<application>`) :
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<queries>
  <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
</queries>
```
Liens profonds (https://whatstore.store/s/... et /p/...) : dans la balise `<activity>` principale :
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="https" android:host="whatstore.store" android:pathPrefix="/s/"/>
  <data android:scheme="https" android:host="whatstore.store" android:pathPrefix="/p/"/>
</intent-filter>
```
Publie sur ton site `https://whatstore.store/.well-known/assetlinks.json` (empreinte SHA-256 de ta clé de signature).

## iOS — `frontend/ios/Runner/Info.plist`
```xml
<key>NSPhotoLibraryUsageDescription</key><string>Choisir des photos de produits</string>
<key>NSPhotoLibraryAddUsageDescription</key><string>Enregistrer des images dans ta galerie</string>
<key>NSCameraUsageDescription</key><string>Prendre des photos de produits</string>
<key>NSMicrophoneUsageDescription</key><string>Enregistrer des vidéos de produits</string>
<key>LSApplicationQueriesSchemes</key><array><string>tel</string><string>https</string></array>
```
Liens universels : Xcode > Signing & Capabilities > Associated Domains : `applinks:whatstore.store`, et publie `https://whatstore.store/.well-known/apple-app-site-association`.

## Signature et publication
- Android : créer un keystore (`keytool -genkey -v -keystore whatstore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias whatstore`), le référencer dans `frontend/android/key.properties` et `frontend/android/app/build.gradle`, puis lancer `flutter build appbundle` depuis `frontend/`.
- iOS : compte Apple Developer, identifiant `store.whatstore.whatstore`, puis `flutter build ipa`.
- Notifications push (plus tard) : Firebase Cloud Messaging ; l'enregistrement du jeton se fera via une opération `device.register`.
