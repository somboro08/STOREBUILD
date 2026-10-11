import 'package:flutter/material.dart';
import '../brand.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import '../widgets/verified_badge.dart';
import 'channel_feed_screen.dart';
import 'create_store_screen.dart';
import 'orders_screen.dart';
import 'publish_product_screen.dart';
import 'reviews_screen.dart';

/// Tableau de bord vendeur : produits, commandes reçues, revenus et retraits.
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
          bottom: TabBar(indicatorColor: C.green, labelColor: C.green, unselectedLabelColor: C.sub, tabs: [Tab(text: 'Produits'), Tab(text: 'Commandes'), Tab(text: 'Revenus')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublishProductScreen(channel: channel))),
          backgroundColor: C.green, foregroundColor: Colors.black,
          icon: Icon(Icons.add), label: Text('Publier'),
        ),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => TabBarView(children: [_products(context), _orders(context), _finance(context)]),
        ),
      ),
    );
  }

  Widget _products(BuildContext context) {
    final list = channel.posts.where((p) => p.isProduct).toList();
    final ann = channel.posts.length - list.length;
    if (list.isEmpty) return Center(child: Text('Aucun produit. Appuie sur « Publier ».', style: TextStyle(color: C.sub)));
    return ListView(padding: EdgeInsets.only(bottom: 90), children: [
      if (ann > 0) Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 0), child: Text('$ann annonce(s) publiée(s) · appui long dans la boutique pour les modifier', style: TextStyle(color: C.sub, fontSize: 12.5))),
      for (final p in list)
        ListTile(
          leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 56, child: ProductImage(color: p.color, bytes: p.bytes, url: p.imageUrl))),
          title: Text(p.title!, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${fmtInt(p.price!)} F · ${p.category ?? 'Autres'} · ${p.sold ? 'Terminé' : (p.stock != null ? '${p.stock} en stock' : 'Disponible')}', style: TextStyle(color: p.sold ? Colors.redAccent : C.sub, fontSize: 13)),
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
            Row(children: [Expanded(child: Text('Commande ${o.ref}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))), StatusChip(o.status, refunded: o.refunded)]),
            SizedBox(height: 4),
            Text('${o.buyerName} · ${o.phone}', style: TextStyle(color: C.sub, fontSize: 13)),
            Text(o.delivery ? 'Livraison : ${o.address}' : 'Retrait en boutique', style: TextStyle(color: C.sub, fontSize: 13)),
            SizedBox(height: 8),
            for (final l in o.lines.where((l) => l.channel == channel)) Text('${l.qty} × ${l.post.title}${l.variant.isEmpty ? '' : ' (${l.variant})'}'),
            SizedBox(height: 8),
            Text('${fmtInt(o.totalFor(channel))} FCFA  ·  net ${fmtInt(o.netFor(channel))} F après commission', style: TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 13.5)),
            if (next != null) ...[
              SizedBox(height: 10),
              Row(children: [
                Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => app.setStatus(o, next), child: Text(o.status.action))),
                SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Annuler cette commande ?', 'Le client sera remboursé automatiquement.', ok: 'Annuler', danger: true)) app.cancelOrder(o);
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

  Future<void> _payoutDialog(BuildContext context) async {
    final amount = TextEditingController(text: '${app.balance(channel)}');
    final phone = TextEditingController(text: channel.phone);
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Demander un retrait'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Montant (FCFA)')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Numéro mobile money')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(
            onPressed: () {
              final err = app.requestPayout(channel, int.tryParse(amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0, phone.text.trim());
              Navigator.pop(d);
              toast(context, err ?? 'Retrait demandé');
            },
            child: Text('Valider', style: TextStyle(color: C.green)),
          ),
        ],
      ),
    );
  }

  Widget _finance(BuildContext context) {
    Widget stat(String k, String v) => Expanded(
          child: Container(
            margin: EdgeInsets.all(4),
            padding: EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [Text(v, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.green)), SizedBox(height: 4), Text(k, style: TextStyle(color: C.sub, fontSize: 12.5))]),
          ),
        );
    final rating = app.ratingOf(channel);
    final payouts = app.payouts.where((p) => p.channelId == channel.id).toList();
    return ListView(padding: EdgeInsets.all(12), children: [
      Center(child: ChannelAvatar(color: channel.color, name: channel.name, bytes: channel.logo, url: channel.logoUrl, size: 72)),
      SizedBox(height: 8),
      Center(child: ChannelTitle(channel, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
      SizedBox(height: 12),
      Row(children: [stat('Abonnés', fmtInt(channel.followers)), stat('Produits', '${channel.posts.where((p) => p.isProduct).length}'), stat('Note', rating == null ? '–' : '★ ${rating.toStringAsFixed(1)}')]),
      SizedBox(height: 8),
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Revenus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 10),
          _line('Ventes livrées', '${fmtInt(app.grossSales(channel))} F'),
          _line('Commission Whatstore (${(Brand.commissionRate * 100).round()} %)', '− ${fmtInt(app.commissions(channel))} F'),
          _line('Déjà retiré', '− ${fmtInt(app.paidOut(channel))} F'),
          Divider(color: C.divider),
          _line('Solde disponible', '${fmtInt(app.balance(channel))} F', bold: true),
          _line('En cours (non livré)', '${fmtInt(app.pendingEarnings(channel))} F'),
          SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(46)),
            onPressed: app.balance(channel) >= Brand.minPayout ? () => _payoutDialog(context) : null,
            child: Text('Demander un retrait (min ${fmtInt(Brand.minPayout)} F)'),
          ),
        ]),
      ),
      if (payouts.isNotEmpty) ...[
        SizedBox(height: 14),
        Text('Historique des retraits', style: TextStyle(fontWeight: FontWeight.w600)),
        for (final p in payouts) ListTile(contentPadding: EdgeInsets.zero, title: Text('${fmtInt(p.amount)} F → ${p.phone}'), subtitle: Text('${fmtDate(p.date)} · ${p.status}', style: TextStyle(color: C.sub, fontSize: 12.5))),
      ],
      SizedBox(height: 10),
      ListTile(
        leading: Icon(channel.verified ? Icons.verified : Icons.verified_outlined, color: channel.verified ? C.link : C.sub),
        title: Text(channel.verified ? 'Boutique vérifiée' : 'Boutique non vérifiée'),
        subtitle: Text(channel.verified ? 'Le badge est visible par tes clients.' : 'Contacte ${Brand.supportEmail} pour demander la vérification.', style: TextStyle(color: C.sub, fontSize: 12.5)),
      ),
      ListTile(leading: Icon(Icons.star_outline), title: Text('Voir les avis'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsScreen(channel: channel)))),
      ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modifier la boutique'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStoreScreen(editing: channel)))),
      ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Voir la boutique'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: channel)))),
      ListTile(leading: Icon(Icons.share_outlined), title: Text('Partager le lien de la boutique'), onTap: () => shareLink(context, 's/${channel.id}', message: channel.name)),
    ]);
  }

  Widget _line(String k, String v, {bool bold = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(k, style: TextStyle(color: bold ? C.text : C.sub, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))), Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500))]),
      );
}
