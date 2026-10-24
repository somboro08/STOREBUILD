import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'catalog_item_edit_screen.dart';

/// Une étiquette vierge a été scannée : créer un produit avec ce code ou la rattacher à un produit existant.
class AssociateCodeScreen extends StatefulWidget {
  final Channel channel;
  final String code;
  const AssociateCodeScreen({super.key, required this.channel, required this.code});
  @override
  State<AssociateCodeScreen> createState() => _AssociateCodeScreenState();
}

class _AssociateCodeScreenState extends State<AssociateCodeScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final list = app.itemsOf(ch, all: true).where((i) => normalizeText('${i.title} ${i.code} ${i.location}').contains(normalizeText(q))).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Étiquette ${widget.code}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Text('Cette étiquette n\'est pas encore attribuée.', style: TextStyle(fontSize: 16)),
        SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
          onPressed: () async {
            final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => CatalogItemEditScreen(channel: ch, code: widget.code)));
            if (id != null && context.mounted) Navigator.pop(context);
          },
          icon: Icon(Icons.add),
          label: Text('Créer un nouveau produit'),
        ),
        SizedBox(height: 20),
        Text('Ou la rattacher à un produit existant', style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: 'Chercher dans le catalogue', prefixIcon: Icon(Icons.search), filled: true, fillColor: C.chip, border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none))),
        for (final i in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 48, height: 48, child: ProductImage(color: C.chip, bytes: i.images.firstOrNull, url: i.imageUrls.firstOrNull))),
            title: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('Étiquette actuelle : ${i.code}', style: TextStyle(color: C.sub, fontSize: 12.5)),
            onTap: () async {
              if (await confirmDialog(context, 'Rattacher à « ${i.title} » ?', 'L\'ancienne étiquette ${i.code} ne sera plus utilisée pour ce produit.', ok: 'Rattacher')) {
                app.reassignCode(i, widget.code);
                if (context.mounted) {
                  toast(context, 'Étiquette rattachée');
                  Navigator.pop(context);
                }
              }
            },
          ),
      ]),
    );
  }
}
