import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data.dart';
import '../services/image_embed.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'catalog_item_screen.dart';

/// Recherche par photo : on photographie un produit, l'app propose les fiches les plus ressemblantes.
/// pick = true : renvoie l'identifiant du produit choisi (utilisé par la caisse).
class PhotoSearchScreen extends StatefulWidget {
  final Channel? channel;
  final bool pick;
  const PhotoSearchScreen({super.key, this.channel, this.pick = false});
  @override
  State<PhotoSearchScreen> createState() => _PhotoSearchScreenState();
}

class _PhotoSearchScreenState extends State<PhotoSearchScreen> {
  Uint8List? photo;
  List<double> sig = [];
  List<MapEntry<CatalogItem, double>> results = [];
  bool busy = false;

  Future<void> _take(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 800, imageQuality: 80);
    if (x == null) return;
    setState(() => busy = true);
    final b = await x.readAsBytes();
    final s = await imageEmbedder.embed(b);
    for (final i in app.items.where((i) => i.active && i.images.isNotEmpty && i.sigs.length != i.images.length).toList()) {
      await app.ensureSigs(i);
    }
    if (!mounted) return;
    setState(() {
      photo = b;
      sig = s;
      results = s.isEmpty ? [] : app.searchByPhoto(s, channel: widget.channel);
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    return Scaffold(
      appBar: AppBar(title: Text('Recherche par photo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        if (photo != null) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(photo!, height: 200, fit: BoxFit.cover)),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(48)), onPressed: busy ? null : () => _take(ImageSource.camera), icon: Icon(Icons.photo_camera_outlined), label: Text('Photographier'))),
          SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(48)), onPressed: busy ? null : () => _take(ImageSource.gallery), icon: Icon(Icons.photo_library_outlined), label: Text('Galerie'))),
        ]),
        SizedBox(height: 8),
        Text('Suggestions basées sur les couleurs et la forme des photos du catalogue. Vérifie toujours le produit avant de valider.', style: TextStyle(color: C.sub, fontSize: 12.5)),
        if (busy) Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (!busy && photo != null && results.isEmpty)
          Padding(padding: EdgeInsets.all(24), child: Text('Aucun produit avec photo à comparer. Ajoute des photos aux produits du catalogue (3 à 4 angles).', style: TextStyle(color: C.sub))),
        for (final r in results)
          Container(
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 56, child: ProductImage(color: C.chip, bytes: r.key.images.firstOrNull, url: r.key.imageUrls.firstOrNull))),
              title: Text(r.key.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Ressemblance ${(r.value * 100).round()} % · ${r.key.availability}${r.key.location.isEmpty ? '' : ' · ${r.key.location}'}', style: TextStyle(color: C.sub, fontSize: 12.5)),
              trailing: (ch?.canCatalog ?? false) && photo != null
                  ? IconButton(
                      tooltip: 'Ajouter cette photo à la fiche',
                      icon: Icon(Icons.add_photo_alternate_outlined),
                      onPressed: () {
                        r.key.images.add(photo!);
                        r.key.sigs.add(sig);
                        app.saveItem(r.key);
                        toast(context, 'Photo ajoutée : la reconnaissance s\'améliore');
                      },
                    )
                  : null,
              onTap: () {
                if (widget.pick) {
                  Navigator.pop(context, r.key.id);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogItemScreen(itemId: r.key.id)));
                }
              },
            ),
          ),
      ]),
    );
  }
}
