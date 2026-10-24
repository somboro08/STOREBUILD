import 'dart:math';
import '../data.dart';

/// Lecture d'un CSV (séparateur , ; ou tabulation détecté, guillemets gérés, BOM ignoré).
List<List<String>> parseCsv(String text) {
  final t = text.startsWith('\uFEFF') ? text.substring(1) : text;
  final first = t.split('\n').first;
  final delim = [';', '\t', ','].reduce((a, b) => first.split(a).length >= first.split(b).length ? a : b);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var q = false;
  void endRow() {
    row.add(cell.toString().trim());
    cell.clear();
    if (row.any((x) => x.isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (q) {
      if (c == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          q = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      q = true;
    } else if (c == delim) {
      row.add(cell.toString().trim());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < t.length && t[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Écriture CSV (séparateur ;, BOM pour qu'Excel lise bien les accents).
String toCsv(List<List<String>> rows, {String delim = ';'}) {
  String esc(String c) => (c.contains(delim) || c.contains('"') || c.contains('\n')) ? '"${c.replaceAll('"', '""')}"' : c;
  return '\uFEFF${rows.map((r) => r.map(esc).join(delim)).join('\r\n')}';
}

/// "1 500", "1.500", "1500,00", "1,500.50" -> entier.
int parseAmount(String s) {
  var t = s.replaceAll(RegExp(r'[^\d,.]'), '');
  if (t.isEmpty) return 0;
  final lc = t.lastIndexOf(','), ld = t.lastIndexOf('.');
  final last = max(lc, ld);
  if (last >= 0) {
    final frac = t.length - last - 1;
    if (frac == 3 && (lc < 0 || ld < 0)) {
      t = t.replaceAll(RegExp(r'[,.]'), '');
    } else {
      t = '${t.substring(0, last).replaceAll(RegExp(r'[,.]'), '')}.${t.substring(last + 1)}';
    }
  }
  return (double.tryParse(t) ?? 0).round();
}

const importFields = {
  'name': 'Nom',
  'barcode': 'Code-barres',
  'price': 'Prix de vente',
  'cost': 'Prix d\'achat',
  'stock': 'Stock',
  'group': 'Sous-catalogue',
  'location': 'Emplacement',
  'unit': 'Unité',
  'description': 'Description',
  'usage': 'À quoi ça sert',
  'variant': 'Variante',
  'low': 'Alerte stock faible',
};

/// Devine le champ correspondant à un en-tête de colonne (ex. "Désignation" -> name).
String? mapHeader(String header) {
  final h = normalizeText(header).replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
  bool any(List<String> keys) => keys.any((k) => h == k || h.startsWith('$k ') || h.endsWith(' $k'));
  if (any(['code barres', 'codebarres', 'code barre', 'barcode', 'ean', 'gtin'])) return 'barcode';
  if (any(['nom', 'name', 'produit', 'designation', 'article', 'libelle'])) return 'name';
  if (any(['prix achat', 'cout', 'cost', 'achat', 'prix d achat', 'pa'])) return 'cost';
  if (any(['prix', 'price', 'prix vente', 'prix de vente', 'pv'])) return 'price';
  if (any(['stock', 'quantite', 'qte', 'qty'])) return 'stock';
  if (any(['sous catalogue', 'catalogue', 'categorie', 'famille', 'groupe'])) return 'group';
  if (any(['emplacement', 'rayon', 'location', 'etagere'])) return 'location';
  if (any(['unite', 'unit'])) return 'unit';
  if (any(['description', 'details'])) return 'description';
  if (any(['usage', 'utilisation', 'a quoi ca sert'])) return 'usage';
  if (any(['variante', 'variant', 'taille', 'couleur'])) return 'variant';
  if (any(['alerte', 'seuil', 'stock mini', 'stock minimum'])) return 'low';
  return null;
}
