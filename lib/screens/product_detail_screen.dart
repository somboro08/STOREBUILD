import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cart_button.dart';
import '../widgets/contact_buttons.dart';
import '../widgets/helpers.dart';
import '../widgets/verified_badge.dart';
import 'cart_screen.dart';
import 'channel_feed_screen.dart';
import 'media_viewer_screen.dart';
import 'reviews_screen.dart';

/// Détail d'un produit : photos, options, stock, avis, contact, panier.
class ProductDetailScreen extends StatefulWidget {
  final Channel channel;
  final Post post;
  const ProductDetailScreen({super.key, required this.channel, required this.post});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int qty = 1, page = 0;
  String? variant;
  Post get post => widget.post;
  Channel get channel => widget.channel;

  List<Widget> _pages() {
    final h = 300.0;
    if (post.allImages.isNotEmpty) return [for (final b in post.allImages) Image.memory(b, fit: BoxFit.cover, width: double.infinity, height: h)];
    final urls = [if (post.imageUrl != null) post.imageUrl!, ...post.extraUrls];
    if (urls.isNotEmpty) return [for (final u in urls) ProductImage(color: post.color, url: u, height: h)];
    return [ProductImage(color: post.color, height: h)];
  }

  bool _ready() {
    if (post.variants.isNotEmpty && variant == null) {
      toast(context, 'Choisis une option');
      return false;
    }
    return true;
  }

  void _add({bool buy = false}) {
    if (!_ready()) return;
    final ok = app.addToCart(channel, post, qty, variant ?? '');
    if (buy) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen()));
    } else {
      toast(context, ok ? 'Ajouté au panier' : 'Stock limité');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    final stock = post.stock;
    final maxQty = stock ?? 99;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(post.title ?? 'Produit', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
          actions: [
            IconButton(
              tooltip: 'Favori',
              icon: Icon(app.favorites.contains(post.id) ? Icons.favorite : Icons.favorite_border, color: app.favorites.contains(post.id) ? Colors.redAccent : null),
              onPressed: () => app.toggleFavorite(post),
            ),
            IconButton(icon: Icon(Icons.share_outlined), tooltip: 'Partager', onPressed: () => shareLink(context, 'p/${post.id}', message: post.title)),
            CartButton(),
          ],
        ),
        body: ListView(children: [
          SizedBox(
            height: 300,
            child: Stack(children: [
              PageView(onPageChanged: (i) => setState(() => page = i), children: pages),
              if (pages.length > 1)
                Positioned(
                  bottom: 10, left: 0, right: 0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < pages.length; i++)
                      Container(margin: EdgeInsets.symmetric(horizontal: 3), width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: i == page ? Colors.white : Colors.white54)),
                  ]),
                ),
              if (post.hasVideo)
                Positioned(
                  right: 12, bottom: 12,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Color(0xCC000000), foregroundColor: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewerScreen(channel: channel, post: post))),
                    icon: Icon(Icons.play_arrow),
                    label: Text('Vidéo'),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.title ?? 'Produit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('${fmtInt(post.price ?? 0)} FCFA', style: TextStyle(fontSize: 21, color: C.green, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsScreen(channel: channel, postId: post.id))),
                child: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: RatingLine(channel, postId: post.id)),
              ),
              if (post.sold)
                Text('Produit terminé pour le moment', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600))
              else if (stock != null)
                Text(stock <= 5 ? 'Plus que $stock en stock' : '$stock en stock', style: TextStyle(color: stock <= 5 ? Colors.orange : C.sub)),
              if (post.category != null) ...[SizedBox(height: 10), Chip(label: Text(post.category!), backgroundColor: C.chip, side: BorderSide.none)],
              SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: channel))),
                child: Row(children: [
                  ChannelAvatar(color: channel.color, name: channel.name, bytes: channel.logo, url: channel.logoUrl, size: 30),
                  SizedBox(width: 10),
                  Expanded(child: Row(children: [Text('Vendu par ', style: TextStyle(color: C.sub, fontSize: 14.5)), Flexible(child: ChannelTitle(channel, style: TextStyle(color: C.link, fontSize: 14.5)))])),
                ]),
              ),
              SizedBox(height: 18),
              Text(post.text, style: TextStyle(fontSize: 16, height: 1.4)),
              if (post.variants.isNotEmpty) ...[
                SizedBox(height: 18),
                Text('Option', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final v in post.variants)
                    ChoiceChip(
                      label: Text(v), selected: variant == v, showCheckmark: false,
                      backgroundColor: C.chip, selectedColor: C.greenPill,
                      side: BorderSide(color: variant == v ? C.green : Colors.transparent),
                      labelStyle: TextStyle(color: variant == v ? C.green : C.text),
                      onSelected: (_) => setState(() => variant = v),
                    ),
                ]),
              ],
              if (!post.sold) ...[
                SizedBox(height: 22),
                Row(children: [
                  Text('Quantité', style: TextStyle(fontSize: 16)),
                  Spacer(),
                  IconButton.filledTonal(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: Icon(Icons.remove)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('$qty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  IconButton.filledTonal(onPressed: qty < maxQty ? () => setState(() => qty++) : null, icon: Icon(Icons.add)),
                ]),
              ],
              SizedBox(height: 22),
              Text('Une question ? Contacte le vendeur', style: TextStyle(color: C.sub)),
              SizedBox(height: 8),
              ContactButtons(phone: channel.phone, message: 'Bonjour, je suis intéressé(e) par « ${post.title} » (${fmtInt(post.price ?? 0)} FCFA) sur Whatstore.'),
              SizedBox(height: 20),
            ]),
          ),
        ]),
        bottomNavigationBar: post.sold
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _add(), child: Text('Ajouter au panier'))),
                    SizedBox(width: 12),
                    Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => _add(buy: true), child: Text('Acheter'))),
                  ]),
                ),
              ),
      ),
    );
  }
}
