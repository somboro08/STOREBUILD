import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';
import 'create_store_screen.dart';

/// Publier (ou modifier) un produit ou une annonce. Produit : image + catégorie obligatoires.
class PublishProductScreen extends StatefulWidget {
  final Channel? channel;
  final Post? editing;
  const PublishProductScreen({super.key, this.channel, this.editing});
  @override
  State<PublishProductScreen> createState() => _PublishProductScreenState();
}

class _PublishProductScreenState extends State<PublishProductScreen> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController(), price = TextEditingController(), stock = TextEditingController();
  final variants = TextEditingController(), desc = TextEditingController();
  Channel? store;
  int mode = 0; // 0 produit, 1 annonce
  List<Uint8List> images = [];
  String? video, cat;
  bool catError = false;

  @override
  void initState() {
    super.initState();
    store = widget.channel ?? (app.mine.isNotEmpty ? app.mine.first : null);
    final e = widget.editing;
    if (e != null) {
      mode = e.isProduct ? 0 : 1;
      title.text = e.title ?? '';
      price.text = '${e.price ?? ''}';
      stock.text = e.stock?.toString() ?? '';
      variants.text = e.variants.join(', ');
      desc.text = e.text;
      cat = e.category;
      images = List.of(e.allImages);
      video = e.videoPath;
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
      if (images.length >= 5) break;
      images.add(await f.readAsBytes());
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: Duration(minutes: 2));
    if (x == null) return;
    if (await x.length() > 60 * 1024 * 1024) {
      if (mounted) toast(context, 'Vidéo trop lourde (60 Mo maximum)');
      return;
    }
    setState(() => video = x.path);
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

  InputDecoration _dec(String label, {String? suffix, String? hint}) => InputDecoration(
        labelText: label, suffixText: suffix, hintText: hint, filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  void _submit() {
    final product = mode == 0;
    final ok = _form.currentState!.validate();
    if (product) {
      setState(() => catError = cat == null);
      if (images.isEmpty && widget.editing == null) {
        toast(context, 'Ajoute au moins une image du produit');
        return;
      }
      if (!ok || cat == null) return;
    } else if (desc.text.trim().isEmpty && images.isEmpty && video == null) {
      toast(context, 'Écris un message ou ajoute une photo / vidéo');
      return;
    }
    final st = int.tryParse(stock.text.trim());
    final vars = variants.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final priceV = product ? int.parse(price.text.replaceAll(RegExp(r'\D'), '')) : null;
    final text = product ? (desc.text.trim().isEmpty ? title.text.trim() : desc.text.trim()) : desc.text.trim();
    final e = widget.editing;
    if (e != null) {
      app.updatePost(e,
          title: product ? title.text.trim() : null, price: priceV, category: product ? cat : null, text: text,
          bytes: images.isEmpty ? null : images.first, extra: images.length > 1 ? images.sublist(1) : <Uint8List>[],
          stock: product ? st : null, variants: product ? vars : null, videoPath: video);
      Navigator.pop(context);
      return;
    }
    final type = video != null ? PostType.video : (images.isNotEmpty ? PostType.image : PostType.text);
    app.publish(
      store!,
      Post(
        id: 'u${DateTime.now().microsecondsSinceEpoch}', type: type, time: nowHm(),
        title: product ? title.text.trim() : null, price: priceV, category: product ? cat : null,
        stock: product ? st : null, variants: product ? vars : null, text: text,
        bytes: images.isEmpty ? null : images.first, extra: images.length > 1 ? images.sublist(1) : null, videoPath: video,
      ),
    );
    Navigator.pop(context);
  }

  Widget _mediaStrip() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            if (images.length < 5)
              GestureDetector(
                onTap: _chooseSource,
                child: Container(
                  width: 96, margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: C.sub), SizedBox(height: 4), Text('${images.length}/5', style: TextStyle(color: C.sub, fontSize: 12))]),
                ),
              ),
            for (var i = 0; i < images.length; i++)
              Stack(children: [
                Container(width: 96, margin: EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias, child: Image.memory(images[i], fit: BoxFit.cover, height: 96)),
                Positioned(top: 2, right: 10, child: GestureDetector(onTap: () => setState(() => images.removeAt(i)), child: CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)))),
                if (i == 0) Positioned(left: 6, bottom: 4, child: Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text('Couverture', style: TextStyle(color: Colors.white, fontSize: 10)))),
              ]),
          ]),
        ),
        SizedBox(height: 8),
        if (video == null)
          TextButton.icon(onPressed: _pickVideo, icon: Icon(Icons.videocam_outlined), label: Text('Ajouter une vidéo (2 min max)'))
        else
          Chip(
            avatar: Icon(Icons.videocam, size: 18),
            label: Text('Vidéo ajoutée'),
            backgroundColor: C.chip,
            onDeleted: widget.editing == null ? () => setState(() => video = null) : null,
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Publier')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Il te faut d\'abord une boutique pour publier.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
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
    final editing = widget.editing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Modifier la publication' : 'Publier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Form(
        key: _form,
        child: ListView(padding: EdgeInsets.all(16), children: [
          if (!editing)
            SegmentedButton<int>(
              segments: [ButtonSegment(value: 0, label: Text('Produit'), icon: Icon(Icons.shopping_bag_outlined)), ButtonSegment(value: 1, label: Text('Annonce'), icon: Icon(Icons.campaign_outlined))],
              selected: {mode},
              onSelectionChanged: (s) => setState(() => mode = s.first),
            ),
          if (!editing) SizedBox(height: 16),
          if (app.mine.length > 1 && !editing)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<Channel>(
                value: store, decoration: _dec('Boutique'), dropdownColor: C.menu,
                items: [for (final c in app.mine) DropdownMenuItem(value: c, child: Text(c.name))],
                onChanged: (v) => setState(() => store = v),
              ),
            ),
          _mediaStrip(),
          SizedBox(height: 16),
          if (mode == 0) ...[
            TextFormField(controller: title, decoration: _dec('Nom du produit'), validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null),
            SizedBox(height: 12),
            TextFormField(
              controller: price, keyboardType: TextInputType.number, decoration: _dec('Prix', suffix: 'FCFA'),
              validator: (v) => (int.tryParse((v ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0) <= 0 ? 'Prix invalide' : null,
            ),
            SizedBox(height: 12),
            TextFormField(controller: stock, keyboardType: TextInputType.number, decoration: _dec('Stock disponible', hint: 'Vide = illimité')),
            SizedBox(height: 12),
            TextFormField(controller: variants, decoration: _dec('Options (facultatif)', hint: 'Ex : S, M, L ou Rouge, Bleu')),
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
            TextFormField(controller: desc, maxLines: 3, decoration: _dec('Description (facultatif)')),
          ] else
            TextFormField(controller: desc, maxLines: 6, decoration: _dec('Ton message', hint: 'Annonce, liste de prix, nouvel arrivage...')),
          SizedBox(height: 22),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
            onPressed: _submit,
            child: Text(editing ? 'Enregistrer' : 'Publier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
