import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme.dart';
import '../widgets/helpers.dart';
import 'catalog_nav.dart';
import 'photo_search_screen.dart';

/// Scanner un code QR d'étiquette ou un code-barres. pick = true : renvoie le texte lu au lieu d'ouvrir le produit.
class ScanScreen extends StatefulWidget {
  final bool pick;
  const ScanScreen({super.key, this.pick = false});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128, BarcodeFormat.code39],
  );
  final manual = TextEditingController();
  bool handled = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _found(String raw) async {
    if (handled || raw.trim().isEmpty) return;
    handled = true;
    if (widget.pick) {
      Navigator.pop(context, raw.trim());
      return;
    }
    await openScanned(context, raw);
    handled = false;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.pick ? 'Scanner un code' : 'Scanner un produit', style: TextStyle(fontSize: 19)),
          actions: [
            if (!widget.pick) IconButton(icon: Icon(Icons.photo_camera_outlined), tooltip: 'Recherche par photo', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoSearchScreen()))),
            IconButton(icon: Icon(Icons.flash_on), tooltip: 'Lampe', onPressed: () => ctrl.toggleTorch()),
            IconButton(icon: Icon(Icons.cameraswitch_outlined), tooltip: 'Changer de caméra', onPressed: () => ctrl.switchCamera()),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: Stack(alignment: Alignment.center, children: [
              MobileScanner(
                controller: ctrl,
                onDetect: (cap) {
                  final raw = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
                  if (raw != null) _found(raw);
                },
                errorBuilder: (context, error, child) => Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Caméra indisponible. Autorise l\'accès à la caméra, ou saisis le code ci-dessous.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)))),
              ),
              Container(
                width: 240, height: 240,
                decoration: BoxDecoration(border: Border.all(color: C.green, width: 3), borderRadius: BorderRadius.circular(20)),
              ),
            ]),
          ),
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: manual,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(hintText: 'Ou tape le code (ex : K7M2QX)', hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF1A1A1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                    onSubmitted: _found,
                  ),
                ),
                SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size(56, 48)),
                  onPressed: () {
                    if (manual.text.trim().isEmpty) {
                      toast(context, 'Saisis un code');
                      return;
                    }
                    _found(manual.text);
                  },
                  child: Icon(Icons.search),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
