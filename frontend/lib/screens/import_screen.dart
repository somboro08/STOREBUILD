import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data.dart';
import '../services/csv.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Import du catalogue depuis un fichier CSV (Excel : Enregistrer sous > CSV) et export.
class ImportScreen extends StatefulWidget {
  final Channel channel;
  const ImportScreen({super.key, required this.channel});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<List<String>> rows = [];
  Map<String, int> cols = {}; // champ -> index de colonne
  bool update = true, busy = false;
  String? file;
  Channel get ch => widget.channel;

  static const template = [
    ['Nom', 'Code-barres', 'Prix de vente', 'Prix d\'achat', 'Stock', 'Sous-catalogue', 'Emplacement', 'Unité', 'Description', 'À quoi ça sert'],
    ['Cahier 100 pages', '', '500', '300', '40', 'Papeterie > Cahiers', 'Rayon B', 'pièce', 'Cahier spiralé', 'Prendre des notes'],
  ];

  Future<void> _share(String name, String csv) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsString(csv);
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: name);
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true);
    final bytes = r?.files.first.bytes;
    if (bytes == null) return;
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    final parsed = parseCsv(text);
    if (parsed.length < 2) {
      if (mounted) toast(context, 'Fichier vide ou illisible');
      return;
    }
    final m = <String, int>{};
    for (var i = 0; i < parsed.first.length; i++) {
      final f = mapHeader(parsed.first[i]);
      if (f != null && !m.containsKey(f)) m[f] = i;
    }
    setState(() {
      rows = parsed;
      cols = m;
      file = r!.files.first.name;
    });
  }

  String _v(List<String> r, String f) => cols.containsKey(f) && cols[f]! < r.length ? r[cols[f]!].trim() : '';

  CatalogGroup _groupFor(String path) {
    String? parent;
    CatalogGroup? g;
    for (final part in path.split(RegExp(r'[>/]')).map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      g = app.groupsOf(ch, parent).where((x) => normalizeText(x.name) == normalizeText(part)).firstOrNull ?? app.saveGroup(ch, part, parentId: parent);
      parent = g.id;
    }
    return g!;
  }

  Future<void> _import() async {
    setState(() => busy = true);
    var created = 0, updated = 0, skipped = 0;
    for (final r in rows.skip(1)) {
      final name = _v(r, 'name');
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      final variant = _v(r, 'variant'), barcode = _v(r, 'barcode');
      final existing = app.itemsOf(ch, all: true).where((i) => (barcode.isNotEmpty && i.barcodes.contains(barcode)) || (normalizeText(i.name) == normalizeText(name) && normalizeText(i.variant) == normalizeText(variant))).firstOrNull;
      final groupPath = _v(r, 'group');
      final gid = groupPath.isEmpty ? null : _groupFor(groupPath).id;
      if (existing != null) {
        if (!update) {
          skipped++;
          continue;
        }
        if (_v(r, 'price').isNotEmpty) existing.price = parseAmount(_v(r, 'price'));
        if (_v(r, 'cost').isNotEmpty) existing.cost = parseAmount(_v(r, 'cost'));
        if (_v(r, 'location').isNotEmpty) existing.location = _v(r, 'location');
        if (gid != null) existing.groupId = gid;
        if (barcode.isNotEmpty && !existing.barcodes.contains(barcode)) existing.barcodes.add(barcode);
        app.saveItem(existing);
        updated++;
        continue;
      }
      final u = _v(r, 'unit');
      app.saveItem(
        CatalogItem(
          id: 'i${DateTime.now().microsecondsSinceEpoch}$created', channelId: ch.id, code: app.newCode(ch.id), name: name, variant: variant,
          description: _v(r, 'description'), usage: _v(r, 'usage'), location: _v(r, 'location'), unit: itemUnits.contains(u) ? u : 'pièce',
          groupId: gid, barcodes: barcode.isEmpty ? [] : [barcode], price: parseAmount(_v(r, 'price')), cost: parseAmount(_v(r, 'cost')),
          lowStock: _v(r, 'low').isEmpty ? 3 : parseAmount(_v(r, 'low')),
        ),
        initialStock: parseAmount(_v(r, 'stock')),
      );
      created++;
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      rows = [];
    });
    await infoDialog(context, 'Import terminé', '$created produit(s) créé(s), $updated mis à jour, $skipped ignoré(s).\nImprime maintenant les étiquettes depuis le catalogue.');
  }

  @override
  Widget build(BuildContext context) {
    final ok = cols.containsKey('name');
    return Scaffold(
      appBar: AppBar(title: Text('Importer / exporter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Text('Prépare ton catalogue dans Excel, enregistre-le en CSV, puis importe-le. Les colonnes sont reconnues par leur nom (Nom, Prix, Stock, Sous-catalogue...). Un sous-catalogue peut être un chemin : « Papeterie > Cahiers ».', style: TextStyle(color: C.sub, height: 1.4)),
        SizedBox(height: 12),
        Wrap(spacing: 10, children: [
          OutlinedButton.icon(onPressed: () => _share('modele-catalogue.csv', toCsv(template)), icon: Icon(Icons.description_outlined), label: Text('Télécharger le modèle')),
          OutlinedButton.icon(
            onPressed: () => _share('catalogue-${ch.name.replaceAll(' ', '-')}.csv', toCsv([
              ['Nom', 'Variante', 'Code QR', 'Code-barres', 'Prix de vente', 'Prix d\'achat', 'Stock', 'Sous-catalogue', 'Emplacement', 'Unité'],
              for (final i in app.itemsOf(ch, all: true))
                [i.name, i.variant, i.code, i.barcodes.join(' '), '${i.price}', ch.canManage ? '${i.cost}' : '', '${i.stock}', app.groupPath(app.groups.where((g) => g.id == i.groupId).firstOrNull), i.location, i.unit],
            ])),
            icon: Icon(Icons.upload_file),
            label: Text('Exporter mon catalogue'),
          ),
        ]),
        SizedBox(height: 18),
        FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(48)), onPressed: busy ? null : _pick, icon: Icon(Icons.file_open_outlined), label: Text('Choisir un fichier CSV')),
        if (rows.isNotEmpty) ...[
          SizedBox(height: 16),
          Text('$file · ${rows.length - 1} ligne(s)', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final e in importFields.entries) Chip(label: Text('${e.value}${cols.containsKey(e.key) ? ' ✓' : ' ✗'}', style: TextStyle(fontSize: 12, color: cols.containsKey(e.key) ? C.green : C.sub)), backgroundColor: C.chip, visualDensity: VisualDensity.compact),
          ]),
          if (!ok) Padding(padding: EdgeInsets.only(top: 10), child: Text('Colonne « Nom » introuvable : renomme-la dans ton fichier.', style: TextStyle(color: Colors.redAccent))),
          SizedBox(height: 8),
          for (final r in rows.skip(1).take(5)) Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Text('• ${_v(r, 'name')} — ${_v(r, 'price')} F — stock ${_v(r, 'stock')}', style: TextStyle(fontSize: 13, color: C.sub))),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Mettre à jour les produits existants'), subtitle: Text('Même code-barres ou même nom : prix, emplacement et sous-catalogue sont mis à jour (le stock n\'est jamais écrasé).', style: TextStyle(color: C.sub, fontSize: 12.5)), value: update, activeColor: C.green, onChanged: (v) => setState(() => update = v)),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)), onPressed: ok && !busy ? _import : null, child: Text(busy ? 'Import en cours...' : 'Importer ${rows.length - 1} ligne(s)')),
        ],
      ]),
    );
  }
}
