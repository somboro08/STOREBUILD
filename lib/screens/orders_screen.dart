import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Mes commandes (acheteur).
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mes commandes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.orders.isEmpty) {
            return Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucune commande pour le moment.\nTes achats apparaîtront ici.', textAlign: TextAlign.center, style: TextStyle(color: C.sub, fontSize: 15))));
          }
          return ListView.separated(
            padding: EdgeInsets.all(14),
            itemCount: app.orders.length,
            separatorBuilder: (_, __) => SizedBox(height: 10),
            itemBuilder: (_, i) {
              final o = app.orders[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
                child: Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('Commande ${o.ref}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                      StatusChip(o.status),
                    ]),
                    SizedBox(height: 4),
                    Text(fmtDate(o.date), style: TextStyle(color: C.sub, fontSize: 13)),
                    SizedBox(height: 8),
                    Text(o.lines.map((l) => '${l.qty}× ${l.post.title}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 8),
                    Text('${fmtInt(o.total)} FCFA', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final OrderStatus s;
  const StatusChip(this.s, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: s.color.withOpacity(.18), borderRadius: BorderRadius.circular(12)),
        child: Text(s.label, style: TextStyle(color: s.color, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}

/// Détail + suivi d'une commande.
class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  static const steps = [OrderStatus.paid, OrderStatus.confirmed, OrderStatus.ready, OrderStatus.delivered];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande ${order.ref}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final o = order;
          final cur = steps.indexOf(o.status);
          return ListView(padding: EdgeInsets.all(16), children: [
            if (o.status == OrderStatus.cancelled)
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.red.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
                child: Text('Cette commande a été annulée.', style: TextStyle(color: Colors.redAccent)),
              )
            else
              for (var i = 0; i < steps.length; i++)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    CircleAvatar(radius: 12, backgroundColor: i <= cur ? C.green : C.chip, child: Icon(Icons.check, size: 15, color: i <= cur ? Colors.black : C.sub)),
                    if (i < steps.length - 1) Container(width: 2, height: 28, color: i < cur ? C.green : C.chip),
                  ]),
                  SizedBox(width: 14),
                  Padding(padding: EdgeInsets.only(top: 2), child: Text(steps[i].label, style: TextStyle(fontSize: 16, color: i <= cur ? C.text : C.sub, fontWeight: i == cur ? FontWeight.w700 : FontWeight.w400))),
                ]),
            SizedBox(height: 22),
            Text('Articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            SizedBox(height: 8),
            for (final l in o.lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${l.qty} × ${l.post.title}'),
                subtitle: Text(l.channel.name, style: TextStyle(color: C.sub, fontSize: 13)),
                trailing: Text('${fmtInt(l.total)} F'),
              ),
            Divider(color: C.divider),
            Row(children: [
              Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              Text('${fmtInt(o.total)} FCFA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: C.green)),
            ]),
            SizedBox(height: 18),
            _info('Date', fmtDate(o.date)),
            _info('Paiement', '${o.provider} · ${o.phone}'),
            _info('Réception', o.delivery ? 'Livraison : ${o.address}' : 'Retrait en boutique'),
            SizedBox(height: 18),
            if (o.status == OrderStatus.paid)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: BorderSide(color: Colors.redAccent), minimumSize: Size.fromHeight(48)),
                onPressed: () async {
                  if (await confirmDialog(context, 'Annuler la commande ?', 'Le remboursement sera traité par la boutique.', ok: 'Annuler la commande', danger: true)) {
                    app.setStatus(o, OrderStatus.cancelled);
                  }
                },
                child: Text('Annuler la commande'),
              ),
          ]);
        },
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 90, child: Text(k, style: TextStyle(color: C.sub))),
          Expanded(child: Text(v)),
        ]),
      );
}
