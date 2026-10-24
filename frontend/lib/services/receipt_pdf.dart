import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../catalog_models.dart';
import '../data.dart';

String _latin(String s) => s.replaceAll('’', "'").replaceAll('œ', 'oe');
String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _short(String id) => id.length > 8 ? id.substring(id.length - 8) : id;

/// Texte du reçu (à envoyer par WhatsApp / SMS).
String receiptText(String shop, Sale s) {
  final b = StringBuffer('$shop\nReçu ${_short(s.id)} · ${_d(s.date)}\n\n');
  for (final l in s.lines) {
    b.writeln('${l.qty} × ${l.name} — ${fmtInt(l.total)} F');
  }
  b.write('\nTotal : ${fmtInt(s.total)} FCFA (${s.method})\nMerci pour votre achat !');
  return b.toString();
}

/// Reçu au format ticket (80 mm).
Future<Uint8List> buildReceiptPdf(String shop, Sale s) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Text(_latin(shop), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        pw.Text('Reçu ${_short(s.id)}', style: pw.TextStyle(fontSize: 9)),
        pw.Text(_d(s.date), style: pw.TextStyle(fontSize: 9)),
        if (s.cashier.isNotEmpty) pw.Text('Caissier : ${_latin(s.cashier)}', style: pw.TextStyle(fontSize: 9)),
        pw.Divider(),
        for (final l in s.lines)
          pw.Padding(
            padding: pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Expanded(child: pw.Text('${l.qty} x ${_latin(l.name)}', style: pw.TextStyle(fontSize: 10))),
              pw.Text('${fmtInt(l.total)} F', style: pw.TextStyle(fontSize: 10)),
            ]),
          ),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('${fmtInt(s.total)} FCFA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Paiement : ${s.method}', style: pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('Merci pour votre achat !', style: pw.TextStyle(fontSize: 10))),
      ]),
    ),
  );
  return doc.save();
}
