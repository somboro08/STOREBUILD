import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'checkout_screen.dart';

/// Panier : lignes groupées par store.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mon panier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.cart.isEmpty) {
            return Center(child: Text('Ton panier est vide', style: TextStyle(color: C.sub, fontSize: 16)));
          }
          final stores = <Channel>{for (final l in app.cart) l.channel};
          return Column(children: [
            Expanded(
              child: ListView(children: [
                for (final s in stores) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(children: [
                      ChannelAvatar(color: s.color, name: s.name, bytes: s.logo, url: s.logoUrl, size: 26),
                      SizedBox(width: 8),
                      Text(s.name, style: TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  for (final l in app.cart.where((l) => l.channel == s))
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 56, height: 56, child: ProductImage(color: l.post.color, bytes: l.post.bytes, url: l.post.imageUrl)),
                      ),
                      title: Text(l.post.title!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${l.variant.isEmpty ? '' : '${l.variant} · '}${fmtInt(l.post.price!)} F × ${l.qty} = ${fmtInt(l.total)} F', style: TextStyle(color: C.green, fontSize: 13)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: Icon(Icons.remove_circle_outline), onPressed: () => app.setQty(l, l.qty - 1)),
                        Text('${l.qty}', style: TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => app.setQty(l, l.qty + 1)),
                      ]),
                    ),
                  Divider(color: C.divider, thickness: 6),
                ],
              ]),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total', style: TextStyle(color: C.sub, fontSize: 13)),
                      Text('${fmtInt(app.cartTotal)} FCFA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen())),
                    child: Text('Passer au paiement', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
