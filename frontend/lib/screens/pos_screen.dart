import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../data.dart';
import '../services/launcher.dart';
import '../services/receipt_pdf.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'photo_search_screen.dart';
import 'scan_screen.dart';

/// Caisse : on ajoute les produits (scan, photo, recherche, grille), on encaisse ; le stock baisse tout seul.
class PosScreen extends StatefulWidget {
  final Channel channel;
  const PosScreen({super.key, required this.channel});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final cart = <String, int>{};
  final prices = <String, int>{}; // prix modifié (gérant / propriétaire)
  String q = '', method = 'Espèces';
  final phone = TextEditingController();
  Channel get ch => widget.channel;

  int _price(CatalogItem i) => prices[i.id] ?? i.price;
  int get total => cart.entries.fold(0, (a, e) {
        final it = app.itemById(e.key);
        return a + (it == null ? 0 : _price(it) * e.value);
      });
  int get count => cart.values.fold(0, (a, b) => a + b);

  void _add(CatalogItem i, [int n = 1]) {
    setState(() => cart[i.id] = (cart[i.id] ?? 0) + n);
    if (i.stock < (cart[i.id] ?? 0)) toast(context, 'Attention : ${i.stock} en stock seulement');
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ScanScreen(pick: true)));
    if (raw == null || !mounted) return;
    final r = app.resolveScan(raw);
    if (r.kind == ScanKind.item && r.item!.channelId == ch.id) {
      _add(r.item!);
    } else {
      toast(context, 'Produit non reconnu dans cette boutique');
    }
  }

  Future<void> _photo() async {
    final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => PhotoSearchScreen(channel: ch, pick: true)));
    final it = id == null ? null : app.itemById(id);
    if (it != null) _add(it);
  }

  Future<void> _checkout() async {
    final lines = <SaleLine>[];
    for (final e in cart.entries) {
      final it = app.itemById(e.key);
      if (it != null) lines.add(SaleLine(it.id, it.title, e.value, _price(it), it.cost));
    }
    if (lines.isEmpty) return;
    final sale = app.createSale(ch, lines, method: method, customerPhone: phone.text.trim());
    setState(() {
      cart.clear();
      prices.clear();
      phone.clear();
    });
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Vente enregistrée'),
        content: Text('${fmtInt(sale.total)} FCFA · ${sale.method}', style: TextStyle(fontSize: 18, color: C.green, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Printing.layoutPdf(onLayout: (_) => buildReceiptPdf(ch.name, sale), name: 'recu-${sale.id}.pdf'), child: Text('Reçu PDF', style: TextStyle(color: C.link))),
          if (sale.customerPhone.isNotEmpty) TextButton(onPressed: () => openWhatsApp(sale.customerPhone, receiptText(ch.name, sale)), child: Text('WhatsApp', style: TextStyle(color: C.link))),
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Nouvelle vente', style: TextStyle(color: C.green))),
        ],
      ),
    );
  }

  void _cartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bubble,
      builder: (s) => StatefulBuilder(
        builder: (s, set) {
          void both(VoidCallback f) {
            setState(f);
            set(() {});
          }

          final lines = [for (final e in cart.entries) if (app.itemById(e.key) != null) MapEntry(app.itemById(e.key)!, e.value)];
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(s).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Panier · ${fmtInt(total)} FCFA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final l in lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.key.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: InkWell(
                        onTap: ch.canManage
                            ? () async {
                                final c = TextEditingController(text: '${_price(l.key)}');
                                final v = await showDialog<int>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    backgroundColor: C.bubble,
                                    title: Text('Prix de ${l.key.name}'),
                                    content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true),
                                    actions: [TextButton(onPressed: () => Navigator.pop(d, int.tryParse(c.text)), child: Text('OK', style: TextStyle(color: C.green)))],
                                  ),
                                );
                                if (v != null) both(() => prices[l.key.id] = v);
                              }
                            : null,
                        child: Text('${fmtInt(_price(l.key))} F${ch.canManage ? '  (modifier)' : ''}', style: TextStyle(color: C.green)),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: Icon(Icons.remove_circle_outline), onPressed: () => both(() {
                              if (l.value <= 1) {
                                cart.remove(l.key.id);
                              } else {
                                cart[l.key.id] = l.value - 1;
                              }
                            })),
                        Text('${l.value}', style: TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => both(() => cart[l.key.id] = l.value + 1)),
                      ]),
                    ),
                ]),
              ),
              SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final m in payMethods)
                  ChoiceChip(label: Text(m), selected: method == m, showCheckmark: false, onSelected: (_) => both(() => method = m), backgroundColor: C.chip, selectedColor: C.greenPill, side: BorderSide(color: method == m ? C.green : Colors.transparent), labelStyle: TextStyle(color: method == m ? C.green : C.text)),
              ]),
              SizedBox(height: 8),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Téléphone du client (pour envoyer le reçu)', filled: true, fillColor: C.chip, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
                onPressed: lines.isEmpty
                    ? null
                    : () {
                        Navigator.pop(s);
                        _checkout();
                      },
                child: Text('Encaisser ${fmtInt(total)} FCFA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final sold = <String, int>{};
        for (final m in app.movements.where((m) => m.channelId == ch.id && m.kind == 'vente')) {
          sold[m.itemId] = (sold[m.itemId] ?? 0) - m.delta;
        }
        final n = normalizeText(q);
        final list = app.itemsOf(ch, all: true).where((i) => n.isEmpty || normalizeText('${i.title} ${i.code} ${i.barcodes.join(' ')}').contains(n)).toList()
          ..sort((a, b) => (sold[b.id] ?? 0).compareTo(sold[a.id] ?? 0)); // les plus vendus d'abord
        return Scaffold(
          appBar: AppBar(title: Text('Caisse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)), actions: [
            IconButton(icon: Icon(Icons.qr_code_scanner), tooltip: 'Scanner', onPressed: _scan),
            IconButton(icon: Icon(Icons.photo_camera_outlined), tooltip: 'Recherche par photo', onPressed: _photo),
          ]),
          body: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: 'Chercher un produit', prefixIcon: Icon(Icons.search), filled: true, fillColor: C.chip, border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none))),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text('Aucun produit. Ajoute-les dans le catalogue.', style: TextStyle(color: C.sub)))
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 90),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .78, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: list.length,
                      itemBuilder: (_, k) {
                        final i = list[k];
                        final qty = cart[i.id] ?? 0;
                        return GestureDetector(
                          onTap: () => _add(i),
                          child: Container(
                            decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12), border: Border.all(color: qty > 0 ? C.green : Colors.transparent, width: 2)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(
                                child: Stack(fit: StackFit.expand, children: [
                                  ProductImage(color: C.chip, bytes: i.images.firstOrNull, url: i.imageUrls.firstOrNull),
                                  if (qty > 0) Positioned(top: 4, right: 4, child: CircleAvatar(radius: 12, backgroundColor: C.green, child: Text('$qty', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)))),
                                  if (i.out) Positioned(left: 4, bottom: 4, child: Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)), child: Text('Rupture', style: TextStyle(color: Colors.white, fontSize: 10)))),
                                ]),
                              ),
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                                  Text('${fmtInt(i.price)} F', style: TextStyle(fontSize: 12.5, color: C.green, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
          bottomNavigationBar: cart.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14, 6, 14, 10),
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(52)),
                      onPressed: _cartSheet,
                      child: Text('Voir le panier · $count article(s) · ${fmtInt(total)} FCFA', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
