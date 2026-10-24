import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data.dart';
import '../services/label_pdf.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Impression d'étiquettes QR : planche vierge (à associer plus tard en scannant) ou étiquettes de produits précis.
class LabelScreen extends StatefulWidget {
  final Channel channel;
  final List<CatalogItem>? items; // null = étiquettes vierges
  const LabelScreen({super.key, required this.channel, this.items});
  @override
  State<LabelScreen> createState() => _LabelScreenState();
}

class _LabelScreenState extends State<LabelScreen> {
  LabelSize size = LabelSize.medium;
  int blank = 24, copies = 1;
  bool showName = true, showPrice = true, busy = false;
  Channel get ch => widget.channel;
  bool get blankMode => widget.items == null;

  Future<void> _print({required bool share}) async {
    final items = widget.items ?? [];
    if (!blankMode && items.isEmpty) {
      toast(context, 'Aucun produit à imprimer');
      return;
    }
    setState(() => busy = true);
    try {
      final specs = <LabelSpec>[];
      if (blankMode) {
        for (final c in app.createBlankCodes(ch, blank)) {
          specs.add(LabelSpec(app.labelUrl(ch, c), c));
        }
      } else {
        for (final i in items) {
          for (var k = 0; k < copies; k++) {
            specs.add(LabelSpec(app.labelUrl(ch, i.code), i.code, i.title, showPrice && i.price > 0 ? '${fmtInt(i.price)} F' : ''));
          }
        }
      }
      final bytes = await buildLabelsPdf(specs, size, showName: showName && !blankMode);
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: 'etiquettes-whatstore.pdf');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'etiquettes-whatstore.pdf');
      }
    } catch (e) {
      if (mounted) toast(context, 'Impression impossible : $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items ?? [];
    final sample = items.isNotEmpty ? items.first : null;
    final code = sample?.code ?? 'K7M2QX';
    return Scaffold(
      appBar: AppBar(title: Text(blankMode ? 'Étiquettes vierges' : 'Étiquettes des produits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Center(
          child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              QrImageView(data: app.labelUrl(ch, code), size: 110, backgroundColor: Colors.white),
              SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (sample != null && showName && !blankMode) SizedBox(width: 120, child: Text(sample.title, maxLines: 2, style: TextStyle(color: Colors.black87, fontSize: 13))),
                Text(code, style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                if (sample != null && showPrice && !blankMode && sample.price > 0) Text('${fmtInt(sample.price)} F', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
        ),
        SizedBox(height: 8),
        Center(child: Text('Aperçu d\'une étiquette', style: TextStyle(color: C.sub, fontSize: 12.5))),
        SizedBox(height: 18),
        Text('Taille', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(spacing: 8, children: [
          for (final s in LabelSize.values)
            ChoiceChip(label: Text(s.label), selected: size == s, showCheckmark: false, onSelected: (_) => setState(() => size = s), backgroundColor: C.chip, selectedColor: C.greenPill, side: BorderSide(color: size == s ? C.green : Colors.transparent), labelStyle: TextStyle(color: size == s ? C.green : C.text)),
        ]),
        SizedBox(height: 18),
        if (blankMode) ...[
          Text('Nombre d\'étiquettes : $blank', style: TextStyle(fontWeight: FontWeight.w600)),
          Slider(value: blank.toDouble(), min: 6, max: 120, divisions: 19, activeColor: C.green, label: '$blank', onChanged: (v) => setState(() => blank = (v / 6).round() * 6)),
          Text('Colle-les sur tes produits, puis scanne chaque étiquette avec l\'app pour l\'associer à un produit. Les codes générés sont enregistrés dans ta boutique.', style: TextStyle(color: C.sub, fontSize: 13)),
        ] else ...[
          Text('${items.length} produit(s)', style: TextStyle(fontWeight: FontWeight.w600)),
          Row(children: [
            Expanded(child: Text('Exemplaires par produit : $copies')),
            IconButton(onPressed: copies > 1 ? () => setState(() => copies--) : null, icon: Icon(Icons.remove_circle_outline)),
            IconButton(onPressed: copies < 20 ? () => setState(() => copies++) : null, icon: Icon(Icons.add_circle_outline)),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Afficher le nom'), value: showName, activeColor: C.green, onChanged: (v) => setState(() => showName = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Afficher le prix'), value: showPrice, activeColor: C.green, onChanged: (v) => setState(() => showPrice = v)),
        ],
        SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
          onPressed: busy ? null : () => _print(share: false),
          icon: Icon(Icons.print_outlined),
          label: Text(busy ? 'Préparation...' : 'Imprimer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: 10),
        OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(46)), onPressed: busy ? null : () => _print(share: true), icon: Icon(Icons.picture_as_pdf_outlined), label: Text('Enregistrer / envoyer en PDF')),
      ]),
    );
  }
}
