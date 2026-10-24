import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'catalog_item_edit_screen.dart';
import 'catalog_item_screen.dart';
import 'import_screen.dart';
import 'inventory_screen.dart';
import 'label_screen.dart';
import 'photo_search_screen.dart';
import 'scan_screen.dart';

/// Catalogue d'une boutique : sous-catalogues (dossiers) et produits avec leur stock.
class CatalogScreen extends StatefulWidget {
  final Channel channel;
  final String? groupId;
  const CatalogScreen({super.key, required this.channel, this.groupId});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String q = '', filter = 'all';
  Channel get ch => widget.channel;

  Future<void> _groupDialog([CatalogGroup? g]) async {
    final ctrl = TextEditingController(text: g?.name ?? '');
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text(g == null ? 'Nouveau sous-catalogue' : 'Renommer'),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: 'Ex : Cahiers, Sacs, Papeterie')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) app.saveGroup(ch, ctrl.text, existing: g, parentId: widget.groupId);
              Navigator.pop(d);
            },
            child: Text('Enregistrer', style: TextStyle(color: C.green)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) => Padding(
        padding: EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label), selected: filter == value, showCheckmark: false, onSelected: (_) => setState(() => filter = value),
          backgroundColor: C.chip, selectedColor: C.greenPill, side: BorderSide(color: filter == value ? C.green : Colors.transparent),
          labelStyle: TextStyle(color: filter == value ? C.green : C.text, fontSize: 13.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final group = widget.groupId == null ? null : app.groups.where((g) => g.id == widget.groupId).firstOrNull;
        final subs = app.groupsOf(ch, widget.groupId);
        final all = app.itemsOf(ch, all: true);
        var list = q.trim().isNotEmpty
            ? all.where((i) => normalizeText('${i.name} ${i.variant} ${i.code} ${i.barcodes.join(' ')} ${i.location}').contains(normalizeText(q))).toList()
            : app.itemsOf(ch, groupId: widget.groupId);
        if (filter == 'low') list = list.where((i) => i.low).toList();
        if (filter == 'out') list = list.where((i) => i.out).toList();
        final searching = q.trim().isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(group?.name ?? 'Catalogue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            actions: [
              IconButton(icon: Icon(Icons.qr_code_scanner), tooltip: 'Scanner', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen()))),
              IconButton(icon: Icon(Icons.photo_camera_outlined), tooltip: 'Recherche par photo', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoSearchScreen(channel: ch)))),
              if (ch.canCatalog) IconButton(icon: Icon(Icons.create_new_folder_outlined), tooltip: 'Nouveau sous-catalogue', onPressed: () => _groupDialog()),
              if (ch.canCatalog) PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'import') Navigator.push(context, MaterialPageRoute(builder: (_) => ImportScreen(channel: ch)));
                  if (v == 'blank') Navigator.push(context, MaterialPageRoute(builder: (_) => LabelScreen(channel: ch)));
                  if (v == 'shown') Navigator.push(context, MaterialPageRoute(builder: (_) => LabelScreen(channel: ch, items: list)));
                  if (v == 'inventory') Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryScreen(channel: ch)));
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'import', child: Text('Importer / exporter (CSV)')),
                  PopupMenuItem(value: 'blank', child: Text('Imprimer des étiquettes vierges')),
                  PopupMenuItem(value: 'shown', child: Text('Imprimer les étiquettes de cette liste')),
                  PopupMenuItem(value: 'inventory', child: Text('Faire un inventaire')),
                ],
              ),
            ],
          ),
          floatingActionButton: !ch.canCatalog ? null : FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogItemEditScreen(channel: ch, groupId: widget.groupId))),
            backgroundColor: C.green, foregroundColor: Colors.black, icon: Icon(Icons.add), label: Text('Produit'),
          ),
          body: ListView(padding: EdgeInsets.only(bottom: 100), children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(hintText: 'Chercher un produit, un code, un rayon', prefixIcon: Icon(Icons.search), filled: true, fillColor: C.chip, border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none)),
              ),
            ),
            if (widget.groupId == null && !searching)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('${all.length} produit(s) · ${all.where((i) => i.out).length} en rupture · ${all.where((i) => i.low).length} stock faible', style: TextStyle(color: C.sub, fontSize: 13)),
              ),
            SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 12), children: [_chip('Tout', 'all'), _chip('Stock faible', 'low'), _chip('Rupture', 'out')])),
            if (!searching)
              for (final g in subs)
                ListTile(
                  leading: Icon(Icons.folder_outlined, color: C.green, size: 30),
                  title: Text(g.name, style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${app.countIn(ch, g.id)} produit(s)', style: TextStyle(color: C.sub, fontSize: 13)),
                  trailing: !ch.canCatalog ? null : PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'rename') _groupDialog(g);
                      if (v == 'del' && await confirmDialog(context, 'Supprimer « ${g.name} » ?', 'Les produits et sous-dossiers qu\'il contient remontent d\'un niveau.', ok: 'Supprimer', danger: true)) app.deleteGroup(g);
                    },
                    itemBuilder: (_) => [PopupMenuItem(value: 'rename', child: Text('Renommer')), PopupMenuItem(value: 'del', child: Text('Supprimer'))],
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogScreen(channel: ch, groupId: g.id))),
                ),
            if (list.isEmpty && (searching || subs.isEmpty))
              Padding(padding: EdgeInsets.all(40), child: Center(child: Text(searching ? 'Aucun produit trouvé' : 'Aucun produit ici.\nAppuie sur « Produit » pour en ajouter.', textAlign: TextAlign.center, style: TextStyle(color: C.sub)))),
            for (final i in list) _itemTile(context, i),
          ]),
        );
      },
    );
  }

  Widget _itemTile(BuildContext context, CatalogItem i) {
    final color = i.out ? Colors.redAccent : (i.low ? Colors.orange : C.green);
    return ListTile(
      leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 52, height: 52, child: ProductImage(color: C.chip, bytes: i.images.firstOrNull, url: i.imageUrls.firstOrNull))),
      title: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('${i.code}${i.location.isEmpty ? '' : ' · ${i.location}'} · ${fmtInt(i.price)} F', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.sub, fontSize: 13)),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
        child: Text(i.out ? 'Rupture' : '${i.stock} ${i.unit}', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogItemScreen(itemId: i.id))),
    );
  }
}
