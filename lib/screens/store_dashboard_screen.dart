import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'channel_feed_screen.dart';
import 'create_store_screen.dart';
import 'orders_screen.dart';
import 'publish_product_screen.dart';

/// Tableau de bord vendeur : produits, commandes reçues, infos du store.
class StoreDashboardScreen extends StatelessWidget {
  final Channel channel;
  const StoreDashboardScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(channel.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          bottom: TabBar(
            indicatorColor: C.green, labelColor: C.green, unselectedLabelColor: C.sub,
            tabs: [Tab(text: 'Produits'), Tab(text: 'Commandes'), Tab(text: 'Infos')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublishProductScreen(channel: channel))),
          backgroundColor: C.green, foregroundColor: Colors.black,
          icon: Icon(Icons.add), label: Text('Produit'),
        ),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => TabBarView(children: [_products(context), _orders(context), _infos(context)]),
        ),
      ),
    );
  }

  Widget _products(BuildContext context) {
    final list = channel.posts.where((p) => p.isProduct).toList();
    if (list.isEmpty) return Center(child: Text('Aucun produit. Appuie sur « Produit » pour publier.', style: TextStyle(color: C.sub)));
    return ListView(padding: EdgeInsets.only(bottom: 90), children: [
      for (final p in list)
        ListTile(
          leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 56, child: ProductImage(color: p.color, bytes: p.bytes))),
          title: Text(p.title!, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${fmtInt(p.price!)} F · ${p.category ?? 'Autres'} · ${p.sold ? 'Terminé' : 'Disponible'}', style: TextStyle(color: p.sold ? Colors.redAccent : C.sub, fontSize: 13)),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => PublishProductScreen(channel: channel, editing: p)));
              if (v == 'sold') app.toggleSold(p);
              if (v == 'del' && await confirmDialog(context, 'Supprimer ce produit ?', 'Cette action est définitive.', ok: 'Supprimer', danger: true)) app.deletePost(channel, p);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'sold', child: Text(p.sold ? 'Marquer disponible' : 'Marquer terminé')),
              PopupMenuItem(value: 'del', child: Text('Supprimer')),
            ],
          ),
        ),
    ]);
  }

  Widget _orders(BuildContext context) {
    final list = app.sellerOrders(channel);
    if (list.isEmpty) return Center(child: Text('Aucune commande reçue.', style: TextStyle(color: C.sub)));
    return ListView.separated(
      padding: EdgeInsets.all(14),
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = list[i];
        final next = o.status.next;
        return Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('Commande ${o.ref}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))), StatusChip(o.status)]),
            SizedBox(height: 4),
            Text('${o.buyerName} · ${o.phone}', style: TextStyle(color: C.sub, fontSize: 13)),
            Text(o.delivery ? 'Livraison : ${o.address}' : 'Retrait en boutique', style: TextStyle(color: C.sub, fontSize: 13)),
            SizedBox(height: 8),
            for (final l in o.lines.where((l) => l.channel == channel)) Text('${l.qty} × ${l.post.title}'),
            SizedBox(height: 8),
            Text('${fmtInt(o.totalFor(channel))} FCFA', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
            if (next != null) ...[
              SizedBox(height: 10),
              Row(children: [
                Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => app.setStatus(o, next), child: Text(o.status.action))),
                SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Annuler cette commande ?', 'Le client sera notifié.', ok: 'Annuler', danger: true)) app.setStatus(o, OrderStatus.cancelled);
                  },
                  child: Text('Annuler'),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }

  Widget _infos(BuildContext context) {
    final revenue = app.sellerOrders(channel).where((o) => o.status != OrderStatus.cancelled).fold(0, (a, o) => a + o.totalFor(channel));
    Widget stat(String k, String v) => Expanded(
          child: Container(
            margin: EdgeInsets.all(4),
            padding: EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.green)), SizedBox(height: 4), Text(k, style: TextStyle(color: C.sub, fontSize: 12.5))]),
          ),
        );
    return ListView(padding: EdgeInsets.all(12), children: [
      Center(child: ChannelAvatar(color: channel.color, name: channel.name, size: 80)),
      SizedBox(height: 10),
      Center(child: Text(channel.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
      SizedBox(height: 14),
      Row(children: [
        stat('Abonnés', fmtInt(channel.followers)),
        stat('Produits', '${channel.posts.where((p) => p.isProduct).length}'),
        stat('Ventes', '${fmtInt(revenue)} F'),
      ]),
      SizedBox(height: 14),
      ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modifier la boutique'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStoreScreen(editing: channel)))),
      ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Voir la boutique'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: channel)))),
      ListTile(leading: Icon(Icons.link), title: Text('Copier le lien de la boutique'), onTap: () => copyLink(context, 's/${channel.id}')),
    ]);
  }
}
