import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data.dart';
import '../services/services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';
import 'scan_screen.dart';

/// Création / modification d'un produit du catalogue : photos, détails, codes, prix, stock, emplacement.
class CatalogItemEditScreen extends StatefulWidget {
  final Channel channel;
  final CatalogItem? item;
  final String? groupId, code, barcode;
  const CatalogItemEditScreen({super.key, required this.channel, this.item, this.groupId, this.code, this.barcode});
  @override
  State<CatalogItemEditScreen> createState() => _CatalogItemEditScreenState();
}

class _CatalogItemEditScreenState extends State<CatalogItemEditScreen> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController(), desc = TextEditingController(), usage = TextEditingController(), location = TextEditingController();
  final variant = TextEditingController(), price = TextEditingController(), cost = TextEditingController();
  final stock = TextEditingController(), low = TextEditingController(text: '3'), barcodeInput = TextEditingController();
  List<Uint8List> images = [];
  List<String> barcodes = [];
  List<List<TextEditingController>> details = [];
  String unit = 'pièce';
  String? groupId, category;
  Channel get ch => widget.channel;

  @override
  void initState() {
    super.initState();
    groupId = widget.groupId;
    final e = widget.item;
    if (e != null) {
      name.text = e.name;
      desc.text = e.description;
      usage.text = e.usage;
      location.text = e.location;
      variant.text = e.variant;
      price.text = e.price == 0 ? '' : '${e.price}';
      cost.text = e.cost == 0 ? '' : '${e.cost}';
      low.text = '${e.lowStock}';
      images = List.of(e.images);
      barcodes = List.of(e.barcodes);
      details = [for (final d in e.details) [TextEditingController(text: d[0]), TextEditingController(text: d.length > 1 ? d[1] : '')]];
      unit = itemUnits.contains(e.unit) ? e.unit : 'pièce';
      groupId = e.groupId;
      category = e.category;
    } else if (widget.barcode != null) {
      barcodes = [widget.barcode!];
    }
  }

  Future<void> _addImages(ImageSource src) async {
    final picker = ImagePicker();
    List<XFile> files;
    if (src == ImageSource.camera) {
      final x = await picker.pickImage(source: src, maxWidth: 1280, imageQuality: 80);
      files = x == null ? [] : [x];
    } else {
      files = await picker.pickMultiImage(maxWidth: 1280, imageQuality: 80);
    }
    for (final f in files) {
      if (images.length >= 6) break;
      images.add(await f.readAsBytes());
    }
    if (mounted) setState(() {});
  }

  void _chooseSource() => showModalBottomSheet(
        context: context,
        backgroundColor: C.bubble,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: Icon(Icons.photo_camera_outlined), title: Text('Prendre une photo'), onTap: () { Navigator.pop(context); _addImages(ImageSource.camera); }),
            ListTile(leading: Icon(Icons.photo_library_outlined), title: Text('Galerie (plusieurs photos)'), onTap: () { Navigator.pop(context); _addImages(ImageSource.gallery); }),
          ]),
        ),
      );

  void _addBarcode(String v) {
    final b = v.trim();
    if (b.isEmpty || barcodes.contains(b)) return;
    setState(() => barcodes.add(b));
    barcodeInput.clear();
    _suggest(b);
  }

  /// Fiche déjà connue d'autres boutiques (registre partagé) : proposée en pré-remplissage.
  Future<void> _suggest(String barcode) async {
    if (!Services.remote || name.text.trim().isNotEmpty) return;
    final s = await Services.catalog.registry(barcode);
    if (s == null || !mounted) return;
    final use = await confirmDialog(context, 'Produit déjà connu', '« ${s['name']} » est déjà dans le registre partagé. Pré-remplir la fiche (nom, description, usage) ?', ok: 'Pré-remplir');
    if (use && mounted) {
      setState(() {
        name.text = s['name'] ?? '';
        if (desc.text.isEmpty) desc.text = s['description'] ?? '';
        if (usage.text.isEmpty) usage.text = s['usage'] ?? '';
      });
    }
  }

  Future<void> _scanBarcode() async {
    final r = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ScanScreen(pick: true)));
    if (r != null) _addBarcode(r);
  }

  InputDecoration _dec(String label, {String? hint, String? suffix}) => InputDecoration(
        labelText: label, hintText: hint, suffixText: suffix, filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  int _int(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final e = widget.item;
    final id = e?.id ?? 'i${DateTime.now().microsecondsSinceEpoch}';
    final clash = app.items.any((i) => i.active && i.channelId == ch.id && i.id != id && i.barcodes.any(barcodes.contains));
    if (clash) {
      toast(context, 'Un de ces codes-barres appartient déjà à un autre produit');
      return;
    }
    final item = e ??
        CatalogItem(id: id, channelId: ch.id, code: widget.code ?? app.newCode(ch.id), name: name.text.trim());
    item
      ..name = name.text.trim()
      ..description = desc.text.trim()
      ..usage = usage.text.trim()
      ..location = location.text.trim()
      ..variant = variant.text.trim()
      ..unit = unit
      ..price = _int(price)
      ..cost = _int(cost)
      ..lowStock = _int(low)
      ..groupId = groupId
      ..category = category
      ..barcodes = barcodes
      ..images = images
      ..details = [
        for (final d in details)
          if (d[0].text.trim().isNotEmpty) [d[0].text.trim(), d[1].text.trim()],
      ];
    if (e != null) item.imageUrls = images.isEmpty ? [] : item.imageUrls;
    await app.ensureSigs(item);
    app.saveItem(item, initialStock: e == null ? _int(stock) : 0);
    if (mounted) Navigator.pop(context, item.id);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final tree = app.groupTree(ch);
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Modifier le produit' : 'Nouveau produit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Form(
        key: _form,
        child: ListView(padding: EdgeInsets.all(16), children: [
          Text('Photos (plusieurs angles aident à reconnaître le produit)', style: TextStyle(color: C.sub, fontSize: 13)),
          SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              if (images.length < 6)
                GestureDetector(
                  onTap: _chooseSource,
                  child: Container(width: 96, margin: EdgeInsets.only(right: 8), decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: C.sub), SizedBox(height: 4), Text('${images.length}/6', style: TextStyle(color: C.sub, fontSize: 12))])),
                ),
              for (var i = 0; i < images.length; i++)
                Stack(children: [
                  Container(width: 96, margin: EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias, child: Image.memory(images[i], fit: BoxFit.cover, height: 96)),
                  Positioned(top: 2, right: 10, child: GestureDetector(onTap: () => setState(() => images.removeAt(i)), child: CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)))),
                ]),
            ]),
          ),
          SizedBox(height: 16),
          TextFormField(controller: name, decoration: _dec('Nom du produit'), validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: variant, decoration: _dec('Variante', hint: 'Taille 42, Rouge...'))),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(value: unit, decoration: _dec('Unité'), dropdownColor: C.menu, items: [for (final u in itemUnits) DropdownMenuItem(value: u, child: Text(u))], onChanged: (v) => setState(() => unit = v!)),
            ),
          ]),
          SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: tree.any((e) => e.key.id == groupId) ? groupId : null,
            decoration: _dec('Sous-catalogue'),
            dropdownColor: C.menu,
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('Racine (aucun)')),
              for (final e in tree) DropdownMenuItem<String?>(value: e.key.id, child: Text('${'   ' * e.value}${e.key.name}')),
            ],
            onChanged: (v) => setState(() => groupId = v),
          ),
          SizedBox(height: 12),
          TextFormField(controller: desc, maxLines: 3, decoration: _dec('Description', hint: 'Ce que c\'est, matière, marque...')),
          SizedBox(height: 12),
          TextFormField(controller: usage, maxLines: 3, decoration: _dec('À quoi ça sert / comment l\'utiliser')),
          SizedBox(height: 16),
          Text('Détails (caractéristiques)', style: TextStyle(fontWeight: FontWeight.w600)),
          for (var i = 0; i < details.length; i++)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: TextField(controller: details[i][0], decoration: _dec('Nom', hint: 'Taille'))),
                SizedBox(width: 8),
                Expanded(child: TextField(controller: details[i][1], decoration: _dec('Valeur', hint: 'A4'))),
                IconButton(icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => setState(() => details.removeAt(i))),
              ]),
            ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => details.add([TextEditingController(), TextEditingController()])), icon: Icon(Icons.add), label: Text('Ajouter un détail'))),
          SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(controller: price, keyboardType: TextInputType.number, decoration: _dec('Prix de vente', suffix: 'FCFA'))),
            SizedBox(width: 10),
            Expanded(child: TextFormField(controller: cost, keyboardType: TextInputType.number, decoration: _dec('Prix d\'achat', suffix: 'FCFA'))),
          ]),
          SizedBox(height: 12),
          Row(children: [
            if (!editing) Expanded(child: TextFormField(controller: stock, keyboardType: TextInputType.number, decoration: _dec('Stock initial'))),
            if (!editing) SizedBox(width: 10),
            Expanded(child: TextFormField(controller: low, keyboardType: TextInputType.number, decoration: _dec('Alerte stock faible', hint: '0 = aucune'))),
          ]),
          if (editing) Padding(padding: EdgeInsets.only(top: 6), child: Text('Le stock change par des mouvements (entrée, vente, perte...) depuis la fiche du produit.', style: TextStyle(color: C.sub, fontSize: 12.5))),
          SizedBox(height: 12),
          TextFormField(controller: location, decoration: _dec('Emplacement dans le magasin', hint: 'Rayon B, étagère 2')),
          SizedBox(height: 16),
          Text('Codes-barres existants (facultatif)', style: TextStyle(fontWeight: FontWeight.w600)),
          Padding(padding: EdgeInsets.only(top: 4), child: Text('Le produit a déjà son code QR Whatstore. Ajoute ici le code-barres imprimé sur l\'emballage s\'il y en a un.', style: TextStyle(color: C.sub, fontSize: 12.5))),
          SizedBox(height: 8),
          Wrap(spacing: 8, children: [for (final b in barcodes) Chip(label: Text(b), backgroundColor: C.chip, onDeleted: () => setState(() => barcodes.remove(b)))]),
          Row(children: [
            Expanded(child: TextField(controller: barcodeInput, decoration: _dec('Code-barres'), onSubmitted: _addBarcode)),
            IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => _addBarcode(barcodeInput.text)),
            IconButton(icon: Icon(Icons.qr_code_scanner), onPressed: _scanBarcode),
          ]),
          SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
            onPressed: _save,
            child: Text(editing ? 'Enregistrer' : 'Ajouter au catalogue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
