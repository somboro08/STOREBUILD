import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import 'catalog_screen.dart';
import 'inventory_screen.dart';
import 'photo_search_screen.dart';
import 'pos_screen.dart';
import 'purchases_screen.dart';
import 'reservations_screen.dart';
import 'sales_report_screen.dart';
import 'scan_screen.dart';
import 'stats_screen.dart';
import 'team_screen.dart';

/// Espace « magasin physique » : caisse, catalogue, stock, achats, équipe... selon le rôle de l'utilisateur.
class StoreHubScreen extends StatelessWidget {
  final Channel channel;
  const StoreHubScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final ch = channel;
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData icon, String title, String sub, Widget page) => Container(
          margin: EdgeInsets.fromLTRB(14, 6, 14, 6),
          decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Icon(icon, color: C.green, size: 28),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(sub, style: TextStyle(color: C.sub, fontSize: 13)),
            trailing: Icon(Icons.chevron_right),
            onTap: () => go(page),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(ch.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final alerts = app.lowStockOf(ch).length;
          final pending = app.reservations.where((r) => r.channelId == ch.id && r.active).length;
          return ListView(padding: EdgeInsets.only(bottom: 30), children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(children: [
                Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: C.greenPill, borderRadius: BorderRadius.circular(12)), child: Text(ch.mine ? 'Propriétaire' : (memberRoles[ch.role] ?? ''), style: TextStyle(color: C.green, fontWeight: FontWeight.w600, fontSize: 12.5))),
                SizedBox(width: 10),
                if (alerts > 0) Text('$alerts alerte(s) de stock', style: TextStyle(color: Colors.orange, fontSize: 13)),
              ]),
            ),
            if (ch.canSell) tile(Icons.point_of_sale, 'Caisse', 'Encaisser une vente, imprimer ou envoyer le reçu', PosScreen(channel: ch)),
            tile(Icons.inventory_2_outlined, 'Catalogue et stock', ch.canCatalog ? 'Produits, sous-catalogues, étiquettes QR, import' : 'Consulter les produits et leur emplacement', CatalogScreen(channel: ch)),
            tile(Icons.qr_code_scanner, 'Scanner un produit', 'Étiquette QR ou code-barres', ScanScreen()),
            tile(Icons.photo_camera_outlined, 'Recherche par photo', 'Retrouver un produit en le photographiant', PhotoSearchScreen(channel: ch)),
            tile(Icons.event_available_outlined, 'Réservations', pending > 0 ? '$pending à préparer ou à remettre' : 'Retraits en magasin demandés par les clients', ReservationsScreen(channel: ch)),
            if (ch.canCatalog) tile(Icons.fact_check_outlined, 'Inventaire', 'Compter le stock en scannant', InventoryScreen(channel: ch)),
            if (ch.canSell) tile(Icons.receipt_long_outlined, ch.canManage ? 'Bilan des ventes' : 'Mes ventes', 'Totaux, ventes du jour, annulation', SalesReportScreen(channel: ch)),
            if (ch.canManage) tile(Icons.local_shipping_outlined, 'Achats et arrivages', 'Coût réel avec transport et douane', PurchasesScreen(channel: ch)),
            if (ch.canManage) tile(Icons.insights_outlined, 'Statistiques', 'Meilleures ventes, ruptures, produits qui dorment, demande', StatsScreen(channel: ch)),
            if (ch.mine) tile(Icons.group_outlined, 'Équipe', 'Gérants, vendeurs, magasiniers', TeamScreen(channel: ch)),
          ]);
        },
      ),
    );
  }
}
