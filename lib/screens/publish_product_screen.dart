import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import 'create_store_screen.dart';

/// Publication d'un produit : image + catégorie obligatoires.
class PublishProductScreen extends StatefulWidget {
  final Channel? channel;
  final Post? editing;
  const PublishProductScreen({super.key, this.channel, this.editing});
  @override
  State<PublishProductScreen> createState() => _PublishProductScreenState();
}

class _PublishProductScreenState extends State<PublishProductScreen> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController(), price = TextEditingController(), desc = TextEditingController();
  Channel? store;
  Uint8List? bytes;
  String? cat;
  bool catError = false;

  @override
  void initState() {
    super.initState();
    store = widget.channel ?? (app.mine.isNotEmpty ? app.mine.first : null);
    final e = widget.editing;
    if (e != null) {
      title.text = e.title ?? '';
      price.text = '${e.price ?? ''}';
      desc.text = e.text;
      cat = e.category;
      bytes = e.bytes;
    }
  }

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1280, imageQuality: 80);
    if (x == null) return;
    final b = await x.readAsBytes();
    setState(() => bytes = b);
  }

  void _chooseSource() => showModalBottomSheet(
        context: context,
        backgroundColor: C.bubble,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: Icon(Icons.photo_camera_outlined), title: Text('Prendre une photo'), onTap: () { Navigator.pop(context); _pick(ImageSource.camera); }),
            ListTile(leading: Icon(Icons.photo_library_outlined), title: Text('Galerie'), onTap: () { Navigator.pop(context); _pick(ImageSource.gallery); }),
          ]),
        ),
      );

  InputDecoration _dec(String label, [String? suffix]) => InputDecoration(
        labelText: label, suffixText: suffix, filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  void _submit() {
    final ok = _form.currentState!.validate();
    setState(() => catError = cat == null);
    if (bytes == null && widget.editing == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ajoute une image du produit')));
      return;
    }
    if (!ok || cat == null) return;
    if (widget.editing != null) {
      app.updatePost(widget.editing!, title: title.text.trim(), price: int.parse(price.text.replaceAll(RegExp(r'\D'), '')), category: cat!, text: desc.text.trim().isEmpty ? title.text.trim() : desc.text.trim(), bytes: bytes);
      Navigator.pop(context);
      return;
    }
    app.publish(
      store!,
      Post(
        id: 'u${DateTime.now().microsecondsSinceEpoch}', type: PostType.image, time: nowHm(),
        title: title.text.trim(), price: int.parse(price.text.replaceAll(RegExp(r'\D'), '')),
        category: cat, text: desc.text.trim().isEmpty ? title.text.trim() : desc.text.trim(), bytes: bytes,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Publier un produit')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Il te faut d\'abord une boutique pour publier des produits.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black),
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreateStoreScreen())),
                child: Text('Créer ma boutique'),
              ),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? 'Publier un produit' : 'Modifier le produit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Form(
        key: _form,
        child: ListView(padding: EdgeInsets.all(16), children: [
          GestureDetector(
            onTap: _chooseSource,
            child: Container(
              height: 210,
              decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: bytes == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_outlined, size: 40, color: C.sub), SizedBox(height: 8), Text('Ajouter une image', style: TextStyle(color: C.sub)),
                    ])
                  : Image.memory(bytes!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          SizedBox(height: 16),
          if (app.mine.length > 1)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<Channel>(
                value: store, decoration: _dec('Boutique'), dropdownColor: C.menu,
                items: [for (final c in app.mine) DropdownMenuItem(value: c, child: Text(c.name))],
                onChanged: (v) => setState(() => store = v),
              ),
            ),
          TextFormField(controller: title, decoration: _dec('Nom du produit'), validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null),
          SizedBox(height: 12),
          TextFormField(
            controller: price, keyboardType: TextInputType.number, decoration: _dec('Prix', 'FCFA'),
            validator: (v) => (int.tryParse((v ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0) <= 0 ? 'Prix invalide' : null,
          ),
          SizedBox(height: 16),
          Text('Catégorie *', style: TextStyle(fontWeight: FontWeight.w600, color: catError ? Colors.redAccent : C.text)),
          SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in categories)
              ChoiceChip(
                label: Text(c), selected: cat == c, showCheckmark: false,
                backgroundColor: C.chip, selectedColor: C.greenPill,
                side: BorderSide(color: cat == c ? C.green : (catError ? Colors.redAccent : Colors.transparent)),
                labelStyle: TextStyle(color: cat == c ? C.green : C.text),
                onSelected: (_) => setState(() { cat = c; catError = false; }),
              ),
          ]),
          if (catError) Padding(padding: EdgeInsets.only(top: 6), child: Text('Choisis une catégorie', style: TextStyle(color: Colors.redAccent, fontSize: 12.5))),
          SizedBox(height: 16),
          TextFormField(controller: desc, maxLines: 3, decoration: _dec('Description (optionnel)')),
          SizedBox(height: 22),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
            onPressed: _submit,
            child: Text(widget.editing == null ? 'Publier' : 'Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
