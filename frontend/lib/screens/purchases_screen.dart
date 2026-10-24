import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Achats et arrivages : coût réel par produit (frais de transport et douane répartis), stock mis à jour.
class PurchasesScreen extends StatelessWidget {
  final Channel channel;
  const PurchasesScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Achats et arrivages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewPurchaseScreen(channel: channel))),
        backgroundColor: C.green, foregroundColor: Colors.black, icon: Icon(Icons.add), label: Text('Arrivage'),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.purchases.where((p) => p.channelId == channel.id).toList();
          if (list.isEmpty) return Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Aucun arrivage enregistré.\nÀ chaque arrivage, le stock augmente et le coût d\'achat réel de chaque produit est recalculé.', textAlign: TextAlign.center, style: TextStyle(color: C.sub))));
          return ListView(padding: EdgeInsets.only(bottom: 90), children: [
            for (final p in list)
              ListTile(
                title: Text(p.supplier.isEmpty ? 'Arrivage' : p.supplier, style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${fmtDate(p.date)} · ${p.lines.length} produit(s) · frais ${fmtInt(p.extraCosts)} F\n${p.lines.map((l) => '${l.qty}× ${app.itemById(l.itemId)?.name ?? '?'} (revient à ${fmtInt(l.landed)} F)').join(', ')}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.sub, fontSize: 12.5)),
                isThreeLine: true,
              ),
          ]);
        },
      ),
    );
  }
}

class NewPurchaseScreen extends StatefulWidget {
  final Channel channel;
  const NewPurchaseScreen({super.key, required this.channel});
  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _Line {
  final CatalogItem item;
  final qty = TextEditingController(), cost = TextEditingController();
  _Line(this.item) {
    cost.text = item.cost > 0 ? '${item.cost}' : '';
  }
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final supplier = TextEditingController(), extra = TextEditingController(), note = TextEditingController();
  final lines = <_Line>[];
  int _i(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _add() async {
    final it = await showModalBottomSheet<CatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bubble,
      builder: (s) {
        var q = '';
        return StatefulBuilder(
          builder: (s, set) {
            final list = app.itemsOf(widget.channel, all: true).where((x) => normalizeText('${x.title} ${x.code}').contains(normalizeText(q))).toList();
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
    if (it != null && !lines.any((l) => l.item.id == it.id)) setState(() => lines.add(_Line(it)));
  }

  @override
  Widget build(BuildContext context) {
    final input = [for (final l in lines) if (_i(l.qty) > 0) PurchaseLine(l.item.id, _i(l.qty), _i(l.cost))];
    final landed = input.isEmpty ? <PurchaseLine>[] : app.landedLines(input, _i(extra));
    final value = input.fold(0, (a, l) => a + l.qty * l.unitCost);
    InputDecoration dec(String l, {String? s}) => InputDecoration(labelText: l, suffixText: s, filled: true, fillColor: C.chip, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
    return Scaffold(
      appBar: AppBar(title: Text('Nouvel arrivage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        TextField(controller: supplier, decoration: dec('Fournisseur')),
        SizedBox(height: 12),
        TextField(controller: extra, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: dec('Frais (transport, douane...)', s: 'FCFA')),
        SizedBox(height: 16),
        Text('Produits reçus', style: TextStyle(fontWeight: FontWeight.w600)),
        for (final l in lines)
          Container(
            margin: EdgeInsets.only(top: 10),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(l.item.title, style: TextStyle(fontWeight: FontWeight.w600))), IconButton(icon: Icon(Icons.close), onPressed: () => setState(() => lines.remove(l)))]),
              Row(children: [
                Expanded(child: TextField(controller: l.qty, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: dec('Quantité'))),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: l.cost, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: dec('Prix d\'achat unitaire'))),
              ]),
              if (landed.any((x) => x.itemId == l.item.id))
                Padding(padding: EdgeInsets.only(top: 8), child: Text('Revient à ${fmtInt(landed.firstWhere((x) => x.itemId == l.item.id).landed)} F l\'unité avec les frais (prix de vente ${fmtInt(l.item.price)} F)', style: TextStyle(color: C.green, fontSize: 13))),
            ]),
          ),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _add, icon: Icon(Icons.add), label: Text('Ajouter un produit'))),
        if (input.isNotEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Total marchandises ${fmtInt(value)} F + frais ${fmtInt(_i(extra))} F = ${fmtInt(value + _i(extra))} F', style: TextStyle(fontWeight: FontWeight.w600))),
        SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
          onPressed: input.isEmpty
              ? null
              : () {
                  app.savePurchase(widget.channel, supplier.text.trim(), _i(extra), note.text.trim(), input);
                  Navigator.pop(context);
                  toast(context, 'Arrivage enregistré : stock et coûts mis à jour');
                },
          child: Text('Enregistrer l\'arrivage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
