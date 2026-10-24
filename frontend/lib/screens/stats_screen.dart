import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../stats.dart';
import '../theme.dart';
import 'catalog_item_screen.dart';

/// Statistiques : chiffre d'affaires, bénéfice, meilleures ventes, produits qui dorment, ruptures, demande.
class StatsScreen extends StatefulWidget {
  final Channel channel;
  const StatsScreen({super.key, required this.channel});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int days = 7;
  Channel get ch => widget.channel;

  Widget _card(String k, String v, {Color? color}) => Expanded(
        child: Container(
          margin: EdgeInsets.all(4),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color ?? C.green)), SizedBox(height: 4), Text(k, textAlign: TextAlign.center, style: TextStyle(color: C.sub, fontSize: 12))]),
        ),
      );

  Widget _h(String t) => Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 8), child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Statistiques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final st = computeStats(app, ch, days);
          final now = DateTime.now();
          final bars = [for (var i = days - 1; i >= 0; i--) DateTime(now.year, now.month, now.day).subtract(Duration(days: i))];
          final shown = bars.length > 14 ? bars.sublist(bars.length - 14) : bars;
          var maxV = 1;
          for (final d in shown) {
            if ((st.byDay[d] ?? 0) > maxV) maxV = st.byDay[d]!;
          }
          final demand = app.demand.where((d) => d.channelId == ch.id).toList()..sort((a, b) => b.count.compareTo(a.count));
          void open(CatalogItem i) => Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogItemScreen(itemId: i.id)));
          return ListView(padding: EdgeInsets.only(bottom: 30), children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Wrap(spacing: 8, children: [
                for (final d in [7, 30, 90])
                  ChoiceChip(label: Text('$d jours'), selected: days == d, showCheckmark: false, onSelected: (_) => setState(() => days = d), backgroundColor: C.chip, selectedColor: C.greenPill, side: BorderSide(color: days == d ? C.green : Colors.transparent), labelStyle: TextStyle(color: days == d ? C.green : C.text)),
              ]),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(children: [
                Row(children: [_card('Chiffre d\'affaires', '${fmtInt(st.total)} F'), _card('Ventes', '${st.count}'), _card('Bénéfice', '${fmtInt(st.profit)} F')]),
                Row(children: [_card('En magasin', '${fmtInt(st.inStore)} F', color: C.link), _card('En ligne', '${fmtInt(st.online)} F', color: C.link), _card('Valeur du stock', '${fmtInt(st.stockValue)} F', color: Colors.orange)]),
              ]),
            ),
            _h('Ventes par jour'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 110,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final d in shown)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Container(height: 4 + 80 * ((st.byDay[d] ?? 0) / maxV), decoration: BoxDecoration(color: (st.byDay[d] ?? 0) > 0 ? C.green : C.chip, borderRadius: BorderRadius.circular(3))),
                          SizedBox(height: 4),
                          Text('${d.day}', style: TextStyle(color: C.sub, fontSize: 10)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
            _h('Meilleures ventes'),
            if (st.top.isEmpty) Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune vente sur la période', style: TextStyle(color: C.sub))),
            for (final t in st.top)
              ListTile(
                title: Text(t.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${t.qty} vendu(s) · bénéfice ${fmtInt(t.profit)} F', style: TextStyle(color: C.sub, fontSize: 12.5)),
                trailing: Text('${fmtInt(t.revenue)} F', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                onTap: () => open(t.item),
              ),
            _h('En rupture (${st.out.length})'),
            if (st.out.isEmpty) Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune rupture', style: TextStyle(color: C.sub))),
            for (final i in st.out.take(8)) ListTile(dense: true, title: Text(i.title), subtitle: Text(i.location, style: TextStyle(color: C.sub, fontSize: 12.5)), onTap: () => open(i)),
            _h('Produits qui dorment (aucune vente sur $days jours)'),
            if (st.slow.isEmpty) Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Rien à signaler', style: TextStyle(color: C.sub))),
            for (final i in st.slow) ListTile(dense: true, title: Text(i.title), subtitle: Text('${i.stock} en stock · ${fmtInt(i.stock * i.cost)} F immobilisés', style: TextStyle(color: C.sub, fontSize: 12.5)), onTap: () => open(i)),
            _h('Recherchés mais absents'),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Ce que tes clients ont cherché dans ta boutique sans trouver : des idées de produits à ajouter.', style: TextStyle(color: C.sub, fontSize: 12.5))),
            if (demand.isEmpty) Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Rien pour le moment', style: TextStyle(color: C.sub))),
            for (final d in demand.take(10)) ListTile(dense: true, leading: Icon(Icons.search, color: C.sub), title: Text(d.term), trailing: Text('${d.count}×', style: TextStyle(fontWeight: FontWeight.w700))),
          ]);
        },
      ),
    );
  }
}
