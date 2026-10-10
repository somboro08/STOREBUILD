import 'dart:typed_data';
import '../models.dart';

/// Authentification (téléphone + code). Local : accepte tout code à 6 chiffres.
abstract class AuthService {
  Future<void> requestCode(String phone);
  Future<AppUser> verifyCode(String phone, String code, String name);
  Future<AppUser> changePhone(String phone, String code);
  Future<void> deleteAccount();
}

class LocalAuthService implements AuthService {
  @override
  Future<void> requestCode(String phone) async => Future.delayed(const Duration(milliseconds: 300));

  @override
  Future<AppUser> verifyCode(String phone, String code, String name) async {
    if (code.length != 6) throw Exception('Code invalide');
    return AppUser(name, phone);
  }

  @override
  Future<AppUser> changePhone(String phone, String code) async {
    if (code.length != 6) throw Exception('Code invalide');
    return AppUser('', phone);
  }

  @override
  Future<void> deleteAccount() async {}
}

/// Envoi des fichiers (images, vidéos). Retourne l'URL publique, ou null (mode local).
abstract class MediaService {
  Future<String?> upload({Uint8List? bytes, String? path, required String kind});
}

class LocalMediaService implements MediaService {
  @override
  Future<String?> upload({Uint8List? bytes, String? path, required String kind}) async => null;
}

/// Synchronisation avec le serveur. push : true = opération prise en compte (ou définitivement rejetée),
/// false = à réessayer plus tard (hors-ligne, erreur serveur). pull : snapshot serveur, ou null.
abstract class SyncService {
  Future<bool> push(SyncOp op);
  Future<Map<String, dynamic>?> pull();
}

class LocalSyncService implements SyncService {
  @override
  Future<bool> push(SyncOp op) async => true;
  @override
  Future<Map<String, dynamic>?> pull() async => null;
}
