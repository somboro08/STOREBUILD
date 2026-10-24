import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Réservations en magasin. channel != null : vue du personnel de la boutique ; sinon : mes réservations (client).
class ReservationsScreen extends StatefulWidget {
  final Channel? channel;
  const ReservationsScreen({super.key, this.channel});
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => app.expireReservations());
  }

  static const labels = {'pending': 'À préparer', 'ready': 'Prête', 'collected': 'Retirée', 'cancelled': 'Annulée', 'expired': 'Expirée'};

  @override
  Widget build(BuildContext context) {
    final staffView = widget.channel != null;
    return Scaffold(
      appBar: AppBar(title: Text(staffView ? 'Réservations' : 'Mes réservations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.reservations.where((r) => staffView ? r.channelId == widget.channel!.id : r.mine).toList()..sort((a, b) => b.date.compareTo(a.date));
          if (list.isEmpty) return Center(child: Text(staffView ? 'Aucune réservation' : 'Tu n\'as rien réservé', style: TextStyle(color: C.sub)));
          return ListView(padding: EdgeInsets.all(14), children: [
            for (final r in list)
              Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r.qty} × ${r.itemName}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                    Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: (r.active ? C.green : C.sub).withOpacity(.15), borderRadius: BorderRadius.circular(12)), child: Text(labels[r.status] ?? r.status, style: TextStyle(color: r.active ? C.green : C.sub, fontSize: 12.5, fontWeight: FontWeight.w600))),
                  ]),
                  SizedBox(height: 4),
                  if (!staffView) Text(app.channelById(r.channelId)?.name ?? '', style: TextStyle(color: C.sub, fontSize: 13)),
                  if (staffView) Text('${r.name}${r.phone.isEmpty ? '' : ' · ${r.phone}'}', style: TextStyle(color: C.sub, fontSize: 13)),
                  Text(r.active ? 'À retirer avant le ${fmtDate(r.expires)}' : fmtDate(r.date), style: TextStyle(color: C.sub, fontSize: 12.5)),
                  if (r.active) ...[
                    SizedBox(height: 10),
                    Row(children: [
                      if (staffView && r.status == 'pending') Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => app.setReservation(r, 'ready'), child: Text('Prête'))),
                      if (staffView && r.status == 'ready') Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => app.setReservation(r, 'collected'), child: Text('Remise au client'))),
                      if (staffView) SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                        onPressed: () async {
                          if (await confirmDialog(context, 'Annuler la réservation ?', 'Le stock sera restitué.', ok: 'Annuler la réservation', danger: true)) app.setReservation(r, 'cancelled');
                        },
                        child: Text('Annuler'),
                      ),
                    ]),
                  ],
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
