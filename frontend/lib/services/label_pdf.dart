import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum LabelSize { small, medium, large }

extension LabelSizeX on LabelSize {
  String get label => const {LabelSize.small: 'Petite (4,5 × 3 cm)', LabelSize.medium: 'Moyenne (6 × 3,5 cm)', LabelSize.large: 'Grande (9 × 5 cm)'}[this]!;
  double get w => const {LabelSize.small: 4.5, LabelSize.medium: 6.0, LabelSize.large: 9.0}[this]!;
  double get h => const {LabelSize.small: 3.0, LabelSize.medium: 3.5, LabelSize.large: 5.0}[this]!;
  double get font => const {LabelSize.small: 7.0, LabelSize.medium: 8.5, LabelSize.large: 11.0}[this]!;
}

class LabelSpec {
  final String url, code, title, price;
  const LabelSpec(this.url, this.code, [this.title = '', this.price = '']);
}

String _latin(String s) => s.replaceAll('’', "'").replaceAll('œ', 'oe').replaceAll('Œ', 'OE').replaceAll('›', '>');

/// Planche d'étiquettes (QR + code lisible + nom/prix facultatifs) au format A4, prête à imprimer.
Future<Uint8List> buildLabelsPdf(List<LabelSpec> labels, LabelSize size, {bool showName = true}) async {
  const cm = PdfPageFormat.cm;
  final doc = pw.Document();
  final w = size.w * cm, h = size.h * cm;
  final qr = h - 0.5 * cm;

  pw.Widget one(LabelSpec l) => pw.Container(
        width: w,
        height: h,
        padding: pw.EdgeInsets.all(0.15 * cm),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.3, color: PdfColors.grey500)),
        child: pw.Row(children: [
          pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: l.url, width: qr, height: qr),
          pw.SizedBox(width: 0.2 * cm),
          pw.Expanded(
            child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (showName && l.title.isNotEmpty) pw.Text(_latin(l.title), maxLines: 3, style: pw.TextStyle(fontSize: size.font)),
              pw.SizedBox(height: 2),
              pw.Text(l.code, style: pw.TextStyle(fontSize: size.font + 3, fontWeight: pw.FontWeight.bold)),
              if (l.price.isNotEmpty) pw.Text(l.price, style: pw.TextStyle(fontSize: size.font + 1, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        ]),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(1 * cm),
      build: (ctx) => [pw.Wrap(spacing: 0.2 * cm, runSpacing: 0.2 * cm, children: [for (final l in labels) one(l)])],
    ),
  );
  return doc.save();
}
