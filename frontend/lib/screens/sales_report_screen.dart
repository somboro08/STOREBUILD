import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../data.dart';
import '../services/receipt_pdf.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Bilan des ventes en magasin : totaux par période et par mode de paiement, détail, annulation.
class SalesReportScreen extends StatefulWidget {
  final Channel channel;
  const SalesReportScreen({super.key, required this.channel});
  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  int days = 1;
  Channel get ch => widget.channel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final now = DateTime.now();
        final since = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
        var list = app.salesOf(ch, since: since);
        if (!ch.canManage) list = list.where((s) => s.cashier == app.user?.name).toList();
        final valid = list.where((s) => !s.voided).toList();
        final total = valid.fold(0, (a, s) => a + s.total);
        final profit = valid.fold(0, (a, s) => a + s.profit);
        final byMethod = <String, int>{};
        for (final s in valid) {
          byMethod[s.method] = (byMethod[s.method] ?? 0) + s.total;
        }
        return Scaffold(
          appBar: AppBar(title: Text(ch.canManage ? 'Bilan des ventes' : 'Mes ventes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
          body: ListView(padding: EdgeInsets.only(bottom: 30), children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Wrap(spacing: 8, children: [
                for (final e in {1: 'Aujourd\'hui', 7: '7 jours', 30: '30 jours'}.entries)
                  ChoiceChip(label: Text(e.value), selected: days == e.key, showCheckmark: false, onSelected: (_) => setState(() => days = e.key), backgroundColor: C.chip, selectedColor: C.greenPill, side: BorderSide(color: days == e.key ? C.green : Colors.transparent), labelStyle: TextStyle(color: days == e.key ? C.green : C.text)),
              ]),
            ),
            Container(
              margin: EdgeInsets.all(14),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${fmtInt(total)} FCFA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: C.green)),
                Text('${valid.length} vente(s)${ch.canManage ? ' · bénéfice ${fmtInt(profit)} F' : ''}', style: TextStyle(color: C.sub)),
                SizedBox(height: 8),
                for (final e in byMethod.entries) Text('${e.key} : ${fmtInt(e.value)} F', style: TextStyle(fontSize: 14)),
              ]),
            ),
            if (list.isEmpty) Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Aucune vente sur cette période', style: TextStyle(color: C.sub)))),
            for (final s in list)
              ListTile(
                title: Text('${fmtInt(s.total)} F · ${s.method}', style: TextStyle(fontWeight: FontWeight.w600, decoration: s.voided ? TextDecoration.lineThrough : null, color: s.voided ? C.sub : null)),
                subtitle: Text('${fmtDate(s.date)} · ${s.cashier}\n${s.lines.map((l) => '${l.qty}× ${l.name}').join(', ')}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.sub, fontSize: 12.5)),
                isThreeLine: true,
                trailing: s.voided ? Text('Annulée', style: TextStyle(color: Colors.redAccent, fontSize: 12.5)) : null,
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: C.bubble,
                  builder: (sheet) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(leading: Icon(Icons.print_outlined), title: Text('Reçu PDF'), onTap: () { Navigator.pop(sheet); Printing.layoutPdf(onLayout: (_) => buildReceiptPdf(ch.name, s), name: 'recu-${s.id}.pdf'); }),
                      if (ch.canManage && !s.voided)
                        ListTile(
                          leading: Icon(Icons.undo, color: Colors.redAccent),
                          title: Text('Annuler la vente', style: TextStyle(color: Colors.redAccent)),
                          onTap: () async {
                            Navigator.pop(sheet);
                            if (await confirmDialog(context, 'Annuler cette vente ?', 'Le stock des produits sera restitué.', ok: 'Annuler la vente', danger: true)) app.voidSale(s);
                          },
                        ),
                    ]),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}
