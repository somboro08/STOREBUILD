import 'package:flutter/material.dart';
import '../brand.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/contact_buttons.dart';
import '../widgets/helpers.dart';
import 'catalog_item_edit_screen.dart';
import 'label_screen.dart';

/// Fiche d'un produit scanné. Client : infos, usage, disponibilité, emplacement.
/// Vendeur de la boutique : en plus stock, mouvements, marge, étiquette, publication en ligne.
class CatalogItemScreen extends StatefulWidget {
  final String itemId;
  const CatalogItemScreen({super.key, required this.itemId});
  @override
  State<CatalogItemScreen> createState() => _CatalogItemScreenState();
}

class _CatalogItemScreenState extends State<CatalogItemScreen> {
  int page = 0;

  Future<void> _stock(CatalogItem it, String kind) async {
    final qty = TextEditingController(), note = TextEditingController();
    final label = kind == 'inventaire' ? 'Corriger le stock' : stockKinds[kind]!;
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text(label),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${it.title} · stock actuel : ${it.stock}', style: TextStyle(color: C.sub, fontSize: 13)),
          TextField(controller: qty, autofocus: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: kind == 'inventaire' ? 'Nouvelle quantité' : 'Quantité')),
          TextField(controller: note, decoration: InputDecoration(labelText: 'Note (facultatif)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(
            onPressed: () {
              final n = int.tryParse(qty.text.trim());
              if (n == null || n < 0) return;
              if (kind == 'inventaire') {
                app.setStockTo(it, n, note: note.text.trim());
              } else {
                app.moveStock(it, (kind == 'vente' || kind == 'perte') ? -n : n, kind, note: note.text.trim());
              }
              Navigator.pop(d);
            },
            child: Text('Valider', style: TextStyle(color: C.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _reserve(CatalogItem it, Channel ch) async {
    final qty = TextEditingController(text: '1'), name = TextEditingController(text: app.user?.name ?? ''), phone = TextEditingController(text: app.user?.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Réserver'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('La boutique garde le produit pour toi pendant ${Brand.reservationHours} h. Tu paies au retrait.', style: TextStyle(color: C.sub, fontSize: 13)),
          TextField(controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantité')),
          TextField(controller: name, decoration: InputDecoration(labelText: 'Ton nom')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Ton téléphone')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Réserver', style: TextStyle(color: C.green))),
        ],
      ),
    );
    if (ok != true) return;
    final n = int.tryParse(qty.text.trim()) ?? 0;
    if (n < 1 || n > it.stock) {
      if (mounted) toast(context, n < 1 ? 'Quantité invalide' : 'Stock insuffisant');
      return;
    }
    app.reserve(it, ch, n, name.text.trim(), phone.text.trim());
    if (mounted) toast(context, 'Réservation envoyée à la boutique');
  }

  Future<void> _publish(CatalogItem it, Channel ch) async {
    var cat = it.category ?? (categories.contains(ch.category) ? ch.category : 'Autres');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          backgroundColor: C.bubble,
          title: Text('Publier en ligne'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Le produit apparaîtra dans ta boutique avec le même stock.', style: TextStyle(color: C.sub, fontSize: 13)),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(value: cat, dropdownColor: C.menu, decoration: InputDecoration(labelText: 'Catégorie en ligne'), items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))], onChanged: (v) => set(() => cat = v!)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: TextStyle(color: C.sub))),
            TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Publier', style: TextStyle(color: C.green))),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (it.price <= 0 && mounted) toast(context, 'Pense à renseigner le prix de vente');
      app.publishItem(it, ch, cat);
    }
  }

  Widget _section(String title, Widget child) => Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: C.sub, fontSize: 13, fontWeight: FontWeight.w600)), SizedBox(height: 6), child]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final it = app.itemById(widget.itemId);
        if (it == null || !it.active) return Scaffold(appBar: AppBar(), body: Center(child: Text('Produit introuvable', style: TextStyle(color: C.sub))));
        final ch = app.channelById(it.channelId);
        final staff = ch?.staff == true;
        final canCat = ch?.canCatalog == true, canMgr = ch?.canManage == true;
        final post = (it.postId == null || ch == null) ? null : ch.posts.where((p) => p.id == it.postId).firstOrNull;
        final color = it.out ? Colors.redAccent : (it.low ? Colors.orange : C.green);
        final pages = it.images.isNotEmpty
            ? [for (final b in it.images) Image.memory(b, fit: BoxFit.cover, width: double.infinity)]
            : (it.imageUrls.isNotEmpty ? [for (final u in it.imageUrls) ProductImage(color: C.chip, url: u)] : [ProductImage(color: C.chip)]);
        final history = app.movements.where((m) => m.itemId == it.id).take(15).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
            actions: [
              if (canCat) IconButton(icon: Icon(Icons.edit_outlined), tooltip: 'Modifier', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogItemEditScreen(channel: ch!, item: it)))),
              if (canCat)
                IconButton(
                  icon: Icon(Icons.delete_outline),
                  tooltip: 'Supprimer',
                  onPressed: () async {
                    if (await confirmDialog(context, 'Supprimer « ${it.title} » ?', 'Le produit disparaît du catalogue et de la boutique en ligne.', ok: 'Supprimer', danger: true)) {
                      app.deleteItem(it);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          body: ListView(padding: EdgeInsets.only(bottom: 30), children: [
            SizedBox(
              height: 280,
              child: Stack(children: [
                PageView(onPageChanged: (i) => setState(() => page = i), children: pages),
                if (pages.length > 1)
                  Positioned(bottom: 10, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < pages.length; i++) Container(margin: EdgeInsets.symmetric(horizontal: 3), width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: i == page ? Colors.white : Colors.white54))])),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Row(children: [
                  Text(it.price > 0 ? '${fmtInt(it.price)} FCFA' : 'Prix sur demande', style: TextStyle(fontSize: 20, color: C.green, fontWeight: FontWeight.w700)),
                  Spacer(),
                  Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(14)), child: Text(it.availability, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                ]),
                if (it.location.isNotEmpty) Padding(padding: EdgeInsets.only(top: 10), child: Row(children: [Icon(Icons.place_outlined, size: 18, color: C.sub), SizedBox(width: 6), Text('Où le trouver : ${it.location}', style: TextStyle(fontSize: 15))])),
              ]),
            ),
            if (it.description.isNotEmpty) _section('Description', Text(it.description, style: TextStyle(fontSize: 15.5, height: 1.4))),
            if (it.usage.isNotEmpty) _section('À quoi ça sert', Text(it.usage, style: TextStyle(fontSize: 15.5, height: 1.4))),
            if (it.details.isNotEmpty)
              _section('Détails', Column(children: [for (final d in it.details) Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(d[0], style: TextStyle(color: C.sub))), Expanded(child: Text(d.length > 1 ? d[1] : ''))]))])),
            if (!staff && ch != null) ...[
              SizedBox(height: 18),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: post != null && !post.sold && !it.out
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
                        onPressed: () => toast(context, app.addToCart(ch, post) ? 'Ajouté au panier' : 'Stock limité'),
                        icon: Icon(Icons.add_shopping_cart),
                        label: Text('Ajouter au panier'),
                      )
                    : Text(it.out ? 'Ce produit est en rupture. Demande au vendeur quand il revient.' : 'Demande au vendeur pour l\'acheter.', style: TextStyle(color: C.sub)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: it.out
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(46)),
                        onPressed: () {
                          app.toggleAlert(it);
                          toast(context, app.alertItems.contains(it.id) ? 'Tu seras prévenu(e) dès son retour' : 'Alerte retirée');
                        },
                        icon: Icon(app.alertItems.contains(it.id) ? Icons.notifications_active : Icons.notifications_none),
                        label: Text(app.alertItems.contains(it.id) ? 'Alerte activée' : 'Prévenez-moi quand il revient'),
                      )
                    : OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(46)), onPressed: () => _reserve(it, ch), icon: Icon(Icons.event_available_outlined), label: Text('Réserver et retirer en magasin (${Brand.reservationHours} h)')),
              ),
              Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: ContactButtons(phone: ch.phone, message: 'Bonjour, à propos de « ${it.title} » dans votre boutique.')),
            ],
            if (staff && ch != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Stock', style: TextStyle(color: C.sub, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('${it.stock} ${it.unit}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: color)),
                    if (it.lowStock > 0) Text('Alerte sous ${it.lowStock}', style: TextStyle(color: C.sub, fontSize: 12.5)),
                    SizedBox(height: 12),
                    if (canCat) Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => _stock(it, 'entree'), icon: Icon(Icons.add), label: Text('Entrée')),
                      OutlinedButton.icon(onPressed: () => _stock(it, 'vente'), icon: Icon(Icons.remove), label: Text('Vente')),
                      OutlinedButton(onPressed: () => _stock(it, 'perte'), child: Text('Perte')),
                      OutlinedButton(onPressed: () => _stock(it, 'retour'), child: Text('Retour')),
                      OutlinedButton(onPressed: () => _stock(it, 'inventaire'), child: Text('Corriger')),
                    ]),
                  ]),
                ),
              ),
              if (canCat) _section('Étiquette', Row(children: [
                Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(8)), child: Text(it.code, style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5))),
                Spacer(),
                OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabelScreen(channel: ch, items: [it]))), icon: Icon(Icons.qr_code_2), label: Text('Réimprimer')),
              ])),
              if (it.barcodes.isNotEmpty) _section('Codes-barres', Wrap(spacing: 8, children: [for (final b in it.barcodes) Chip(label: Text(b), backgroundColor: C.chip)])),
              if (canMgr && it.cost > 0 && it.price > 0) _section('Marge', Text('${fmtInt(it.margin)} F par ${it.unit} (${((it.margin / it.price) * 100).round()} %) · achat ${fmtInt(it.cost)} F', style: TextStyle(fontSize: 15))),
              if (canMgr) _section('Boutique en ligne', post == null
                  ? Row(children: [Expanded(child: Text('Non publié', style: TextStyle(color: C.sub))), FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => _publish(it, ch), child: Text('Publier en ligne'))])
                  : Row(children: [Icon(Icons.check_circle, color: C.green, size: 20), SizedBox(width: 8), Expanded(child: Text('Publié · même stock que le magasin')), TextButton(onPressed: () => app.unpublishItem(it, ch), child: Text('Retirer', style: TextStyle(color: Colors.redAccent)))])),
              if (history.isNotEmpty)
                _section('Historique du stock', Column(children: [
                  for (final m in history)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        SizedBox(width: 48, child: Text('${m.delta > 0 ? '+' : ''}${m.delta}', style: TextStyle(fontWeight: FontWeight.w700, color: m.delta >= 0 ? C.green : Colors.redAccent))),
                        Expanded(child: Text('${stockKinds[m.kind] ?? m.kind}${m.note.isEmpty ? '' : ' · ${m.note}'}\n${fmtDate(m.date)}${m.by.isEmpty ? '' : ' · ${m.by}'}', style: TextStyle(fontSize: 13, color: C.sub))),
                        Text('→ ${m.after}', style: TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ])),
            ],
          ]),
        );
      },
    );
  }
}
