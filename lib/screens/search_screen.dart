import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'product_detail_screen.dart';

/// Recherche de produits avec filtres : texte, catégorie, prix, tri.
class SearchScreen extends StatefulWidget {
  final Channel? channel; // si renseigné : recherche limitée à ce store
  const SearchScreen({super.key, this.channel});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';
  String? cat;
  String sort = 'pertinence';
  RangeValues range = const RangeValues(0, 20000);

  @override
  Widget build(BuildContext context) {
    final res = app.products(widget.channel).where((r) {
      final p = r.post;
      final hay = '${p.title} ${p.text} ${p.category}'.toLowerCase();
      return hay.contains(q.toLowerCase()) && (cat == null || p.category == cat) && p.price! >= range.start && p.price! <= range.end;
    }).toList();
    if (sort == 'asc') res.sort((a, b) => a.post.price!.compareTo(b.post.price!));
    if (sort == 'desc') res.sort((a, b) => b.post.price!.compareTo(a.post.price!));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          onChanged: (v) => setState(() => q = v),
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            hintText: widget.channel == null ? 'Rechercher un produit' : 'Rechercher dans ${widget.channel!.name}',
            border: InputBorder.none,
          ),
        ),
      ),
      body: Column(children: [
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
            _chip('Tous', cat == null, () => setState(() => cat = null)),
            for (final c in categories) _chip(c, cat == c, () => setState(() => cat = c)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(children: [
            Expanded(child: Text('Prix : ${fmtInt(range.start.round())} – ${fmtInt(range.end.round())} FCFA', style: const TextStyle(color: C.sub, fontSize: 13))),
            DropdownButton<String>(
              value: sort,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFF111B21),
              items: const [
                DropdownMenuItem(value: 'pertinence', child: Text('Pertinence')),
                DropdownMenuItem(value: 'asc', child: Text('Prix croissant')),
                DropdownMenuItem(value: 'desc', child: Text('Prix décroissant')),
              ],
              onChanged: (v) => setState(() => sort = v!),
            ),
          ]),
        ),
        RangeSlider(
          values: range, min: 0, max: 20000, divisions: 40,
          activeColor: C.green,
          onChanged: (v) => setState(() => range = v),
        ),
        const Divider(height: 1, color: C.divider),
        Expanded(
          child: res.isEmpty
              ? const Center(child: Text('Aucun produit trouvé', style: TextStyle(color: C.sub)))
              : ListView.builder(
                  itemCount: res.length,
                  itemBuilder: (_, i) {
                    final r = res[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 64, height: 64, child: ProductImage(color: r.post.color, bytes: r.post.bytes)),
                      ),
                      title: Text(r.post.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${r.channel.name} · ${r.post.category ?? 'Autres'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.sub, fontSize: 13)),
                      trailing: Text('${fmtInt(r.post.price!)} F', style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(channel: r.channel, post: r.post))),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label), selected: sel, onSelected: (_) => onTap(), showCheckmark: false,
          backgroundColor: C.chip, selectedColor: C.greenPill,
          side: BorderSide(color: sel ? C.green : Colors.transparent),
          labelStyle: TextStyle(color: sel ? C.green : C.text, fontSize: 13.5),
        ),
      );
}
