import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mes favoris', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.products().where((r) => app.favorites.contains(r.post.id)).toList();
          if (list.isEmpty) return Center(child: Text('Aucun favori. Appuie sur ♡ sur un produit.', style: TextStyle(color: C.sub)));
          return ListView(children: [
            for (final r in list)
              ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 56, child: ProductImage(color: r.post.color, bytes: r.post.bytes, url: r.post.imageUrl))),
                title: Text(r.post.title!, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(r.channel.name, style: TextStyle(color: C.sub, fontSize: 13)),
                trailing: Text('${fmtInt(r.post.price!)} F', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(channel: r.channel, post: r.post))),
              ),
          ]);
        },
      ),
    );
  }
}
