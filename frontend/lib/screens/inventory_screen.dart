import 'dart:math';
import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';
import 'scan_screen.dart';

/// Inventaire : on scanne (ou cherche) les produits un par un, on compte, puis on applique les écarts.
class InventoryScreen extends StatefulWidget {
  final Channel channel;
  const InventoryScreen({super.key, required this.channel});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final counts = <String, int>{};
  Channel get ch => widget.channel;

  void _add(CatalogItem i, [int n = 1]) => setState(() => counts[i.id] = (counts[i.id] ?? 0) + n);

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ScanScreen(pick: true)));
    if (raw == null || !mounted) return;
    final r = app.resolveScan(raw);
    if (r.kind == ScanKind.item && r.item!.channelId == ch.id) {
      _add(r.item!);
      toast(context, '${r.item!.title} : ${counts[r.item!.id]}');
    } else {
      toast(context, 'Code non reconnu dans ce catalogue');
    }
  }

  Future<void> _pick() async {
    final i = await showModalBottomSheet<CatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bubble,
      builder: (s) {
        var q = '';
        return StatefulBuilder(
          builder: (s, set) {
            final list = app.itemsOf(ch, all: true).where((x) => normalizeText('${x.title} ${x.code}').contains(normalizeText(q))).toList();
            return SizedBox(
              height: MediaQuery.of(s).size.height * .75,
              child: Column(children: [
                Padding(padding: EdgeInsets.all(12), child: TextField(autofocus: true, onChanged: (v) => set(() => q = v), decoration: InputDecoration(hintText: 'Chercher un produit', prefixIcon: Icon(Icons.search)))),
                Expanded(child: ListView(children: [for (final x in list) ListTile(title: Text(x.title), subtitle: Text('${x.code} · stock ${x.stock}', style: TextStyle(color: C.sub)), onTap: () => Navigator.pop(s, x))])),
              ]),
            );
          },
        );
      },
    );
    if (i != null) _add(i);
  }

  Future<void> _apply() async {
    final diffs = counts.entries.where((e) => (app.itemById(e.key)?.stock ?? e.value) != e.value).length;
    if (!await confirmDialog(context, 'Appliquer l\'inventaire ?', '${counts.length} produit(s) comptés, $diffs écart(s) seront corrigés dans le stock.', ok: 'Appliquer')) return;
    for (final e in counts.entries) {
      final it = app.itemById(e.key);
      if (it != null) app.setStockTo(it, e.value, note: 'Inventaire');
    }
    if (mounted) {
      toast(context, 'Inventaire appliqué');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = counts.keys.map(app.itemById).whereType<CatalogItem>().toList();
    return Scaffold(
      appBar: AppBar(title: Text('Inventaire', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(46)), onPressed: _scan, icon: Icon(Icons.qr_code_scanner), label: Text('Scanner'))),
            SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(46)), onPressed: _pick, icon: Icon(Icons.search), label: Text('Chercher'))),
          ]),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Scanne chaque produit autant de fois qu\'il y a d\'exemplaires, ou cherche-le et règle la quantité.', textAlign: TextAlign.center, style: TextStyle(color: C.sub))))
              : ListView(children: [
                  for (final i in rows)
                    ListTile(
                      title: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Stock actuel : ${i.stock}${counts[i.id] != i.stock ? '  ·  écart ${(counts[i.id]! - i.stock) > 0 ? '+' : ''}${counts[i.id]! - i.stock}' : ''}', style: TextStyle(color: counts[i.id] == i.stock ? C.sub : Colors.orange, fontSize: 13)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: Icon(Icons.remove_circle_outline), onPressed: () => setState(() => counts[i.id] = max(0, counts[i.id]! - 1))),
                        Text('${counts[i.id]}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => _add(i)),
                      ]),
                    ),
                ]),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
              onPressed: counts.isEmpty ? null : _apply,
              child: Text('Appliquer l\'inventaire (${counts.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}
