import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../data.dart';

/// Stockage local (hors-ligne) : un fichier JSON + un dossier de médias dans les documents de l'app.
class LocalStore implements MediaIO {
  final Directory root;
  LocalStore._(this.root);

  static Future<LocalStore> open() async {
    final base = await getApplicationDocumentsDirectory();
    Directory('${base.path}/whatstore/media').createSync(recursive: true);
    return LocalStore._(Directory('${base.path}/whatstore'));
  }

  File get _file => File('${root.path}/snapshot.json');

  Map<String, dynamic>? readJson() {
    try {
      if (!_file.existsSync()) return null;
      return jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void writeJson(Map<String, dynamic> j) {
    final tmp = File('${root.path}/snapshot.tmp');
    tmp.writeAsStringSync(jsonEncode(j));
    tmp.renameSync(_file.path);
  }

  void wipe() {
    try {
      if (root.existsSync()) root.deleteSync(recursive: true);
      Directory('${root.path}/media').createSync(recursive: true);
    } catch (_) {}
  }

  @override
  String mediaPath(String name) => '${root.path}/media/$name';

  @override
  String? saveImage(String name, Uint8List? bytes) {
    if (bytes == null) return null;
    final file = '$name.jpg';
    final f = File(mediaPath(file));
    if (!f.existsSync() || f.lengthSync() != bytes.length) f.writeAsBytesSync(bytes);
    return file;
  }

  @override
  Uint8List? loadImage(String? name) {
    if (name == null) return null;
    final f = File(mediaPath(name));
    return f.existsSync() ? f.readAsBytesSync() : null;
  }

  @override
  String? importFile(String name, String srcPath) {
    final ext = srcPath.contains('.') ? '.${srcPath.split('.').last}' : '.mp4';
    final dest = mediaPath('$name$ext');
    if (srcPath == dest) return dest;
    File(srcPath).copySync(dest);
    return dest;
  }
}
