import 'package:flutter/material.dart';
import '../services/services.dart';
import '../state.dart';
import '../widgets/helpers.dart';
import 'associate_code_screen.dart';
import 'catalog_item_edit_screen.dart';
import 'catalog_item_screen.dart';

/// Ouvre le bon écran selon ce qui a été scanné : fiche produit, association d'étiquette, création.
Future<void> openScanned(BuildContext context, String raw) async {
  var r = app.resolveScan(raw);
  if (r.kind == ScanKind.unknown && Services.remote) r = await app.resolveScanRemote(raw);
  if (!context.mounted) return;
  switch (r.kind) {
    case ScanKind.item:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogItemScreen(itemId: r.item!.id)));
    case ScanKind.blank:
      if (r.channel != null && r.channel!.mine) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => AssociateCodeScreen(channel: r.channel!, code: r.code!)));
      } else {
        toast(context, 'Cette étiquette n\'est pas encore attribuée à un produit');
      }
    case ScanKind.unknown:
      final mine = app.mine;
      if (mine.isEmpty) {
        toast(context, 'Produit inconnu : $raw');
        return;
      }
      final create = await confirmDialog(context, 'Produit inconnu', 'Le code « $raw » n\'est dans aucun catalogue. L\'ajouter comme code-barres d\'un nouveau produit de ta boutique ?', ok: 'Créer le produit');
      if (create && context.mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogItemEditScreen(channel: mine.first, barcode: raw)));
      }
  }
}
