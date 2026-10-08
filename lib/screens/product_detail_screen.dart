import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cart_button.dart';
import '../widgets/helpers.dart';
import 'cart_screen.dart';
import 'channel_feed_screen.dart';

/// Détail d'un produit : quantité, panier, achat direct.
class ProductDetailScreen extends StatefulWidget {
  final Channel channel;
  final Post post;
  const ProductDetailScreen({super.key, required this.channel, required this.post});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int qty = 1;
  @override
  Widget build(BuildContext context) {
    final post = widget.post, channel = widget.channel;
    return Scaffold(
      appBar: AppBar(title: Text(post.title ?? 'Produit', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)), actions: [
        ListenableBuilder(
          listenable: app,
          builder: (_, __) => IconButton(
            tooltip: 'Favori',
            icon: Icon(app.favorites.contains(post.id) ? Icons.favorite : Icons.favorite_border, color: app.favorites.contains(post.id) ? Colors.redAccent : null),
            onPressed: () => app.toggleFavorite(post),
          ),
        ),
        IconButton(icon: Icon(Icons.share_outlined), tooltip: 'Partager', onPressed: () => copyLink(context, 'p/${post.id}')),
        CartButton(),
      ]),
      body: ListView(children: [
        ProductImage(color: post.color, bytes: post.bytes, height: 300),
        Padding(
          padding: EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.title ?? 'Produit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('${fmtInt(post.price ?? 0)} FCFA', style: TextStyle(fontSize: 21, color: C.green, fontWeight: FontWeight.w700)),
            if (post.category != null) ...[
              SizedBox(height: 10),
              Chip(label: Text(post.category!), backgroundColor: C.chip, side: BorderSide.none),
            ],
            SizedBox(height: 8),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: channel))),
              child: Row(children: [
                ChannelAvatar(color: channel.color, name: channel.name, size: 30),
                SizedBox(width: 10),
                Expanded(child: Text('Vendu par ${channel.name}', style: TextStyle(color: C.link, fontSize: 14.5))),
              ]),
            ),
            SizedBox(height: 18),
            Text(post.text, style: TextStyle(fontSize: 16, height: 1.4)),
            SizedBox(height: 22),
            if (!post.sold)
              Row(children: [
                Text('Quantité', style: TextStyle(fontSize: 16)),
                Spacer(),
                IconButton.filledTonal(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: Icon(Icons.remove)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('$qty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton.filledTonal(onPressed: () => setState(() => qty++), icon: Icon(Icons.add)),
              ])
            else
              Text('Produit terminé pour le moment', style: TextStyle(color: Colors.redAccent)),
          ]),
        ),
      ]),
      bottomNavigationBar: post.sold
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        app.addToCart(channel, post, qty);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ajouté au panier'), duration: Duration(seconds: 1)));
                      },
                      child: Text('Ajouter au panier'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black),
                      onPressed: () {
                        app.addToCart(channel, post, qty);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen()));
                      },
                      child: Text('Acheter'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}
