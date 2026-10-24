import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'product_detail_screen.dart';

/// Recherche de produits : texte (sans accents), catégorie, prix, tri, historique.
class SearchScreen extends StatefulWidget {
  final Channel? channel;
  const SearchScreen({super.key, this.channel});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctrl = TextEditingController();
  String q = '';
  String? cat;
  String sort = 'pertinence';
  RangeValues range = RangeValues(0, 20000);
  bool _empty = false;

  @override
  Widget build(BuildContext context) {
    final n = normalizeText(q);
    final res = app.products(widget.channel).where((r) {
      final p = r.post;
      return normalizeText('${p.title} ${p.text} ${p.category}').contains(n) && (cat == null || p.category == cat) && p.price! >= range.start && (range.end >= 20000 || p.price! <= range.end);
    }).toList();
    _empty = res.isEmpty;
    if (sort == 'asc') res.sort((a, b) => a.post.price!.compareTo(b.post.price!));
    if (sort == 'desc') res.sort((a, b) => b.post.price!.compareTo(a.post.price!));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => q = v),
          onSubmitted: (v) {
            app.addSearch(v);
            if (widget.channel != null && _empty && v.trim().length >= 3) app.logDemand(widget.channel!, v);
          },
          style: TextStyle(fontSize: 17),
          decoration: InputDecoration(hintText: widget.channel == null ? 'Rechercher un produit' : 'Rechercher dans ${widget.channel!.name}', border: InputBorder.none),
        ),
      ),
      body: Column(children: [
        if (q.isEmpty && app.searchHistory.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('Recherches récentes', style: TextStyle(color: C.sub, fontSize: 13))), TextButton(onPressed: app.clearSearchHistory, child: Text('Effacer', style: TextStyle(color: C.link)))]),
              Wrap(spacing: 8, children: [
                for (final h in app.searchHistory)
                  ActionChip(
                    label: Text(h), backgroundColor: C.chip,
                    onPressed: () => setState(() {
                      q = h;
                      ctrl.text = h;
                    }),
                  ),
              ]),
            ]),
          ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
            _chip('Tous', cat == null, () => setState(() => cat = null)),
            for (final c in categories) _chip(c, cat == c, () => setState(() => cat = c)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(children: [
            Expanded(child: Text('Prix : ${fmtInt(range.start.round())} – ${range.end >= 20000 ? '20 000+' : fmtInt(range.end.round())} FCFA', style: TextStyle(color: C.sub, fontSize: 13))),
            DropdownButton<String>(
              value: sort,
              underline: SizedBox(),
              dropdownColor: C.menu,
              items: [
                DropdownMenuItem(value: 'pertinence', child: Text('Pertinence')),
                DropdownMenuItem(value: 'asc', child: Text('Prix croissant')),
                DropdownMenuItem(value: 'desc', child: Text('Prix décroissant')),
              ],
              onChanged: (v) => setState(() => sort = v!),
            ),
          ]),
        ),
        RangeSlider(values: range, min: 0, max: 20000, divisions: 40, activeColor: C.green, onChanged: (v) => setState(() => range = v)),
        Divider(height: 1, color: C.divider),
        Expanded(
          child: res.isEmpty
              ? Center(child: Text('Aucun produit trouvé', style: TextStyle(color: C.sub)))
              : ListView.builder(
                  itemCount: res.length,
                  itemBuilder: (_, i) {
                    final r = res[i];
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 64, height: 64, child: ProductImage(color: r.post.color, bytes: r.post.bytes, url: r.post.imageUrl))),
                      title: Text(r.post.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${r.channel.name} · ${r.post.category ?? 'Autres'}${r.post.sold ? ' · Terminé' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.sub, fontSize: 13)),
                      trailing: Text('${fmtInt(r.post.price!)} F', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                      onTap: () {
                        app.addSearch(q);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(channel: r.channel, post: r.post)));
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label), selected: sel, onSelected: (_) => onTap(), showCheckmark: false,
          backgroundColor: C.chip, selectedColor: C.greenPill,
          side: BorderSide(color: sel ? C.green : Colors.transparent),
          labelStyle: TextStyle(color: sel ? C.green : C.text, fontSize: 13.5),
        ),
      );
}
