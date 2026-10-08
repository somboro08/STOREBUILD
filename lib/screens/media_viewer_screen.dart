import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'product_detail_screen.dart';

/// Visionneuse plein écran d'un média de la chaîne.
class MediaViewerScreen extends StatelessWidget {
  final Channel channel;
  final Post post;
  const MediaViewerScreen({super.key, required this.channel, required this.post});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(channel.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Text('Aujourd\'hui, ${post.time}', style: TextStyle(fontSize: 13, color: C.sub)),
        ]),
        actions: [
          IconButton(icon: Icon(Icons.file_download_outlined), tooltip: 'Enregistrer', onPressed: () => toast(context, 'Image enregistrée dans la galerie (à brancher)')),
          IconButton(icon: Icon(Icons.shortcut), tooltip: 'Partager', onPressed: () => copyLink(context, 'p/${post.id}')),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'fav') app.toggleFavorite(post);
              if (v == 'report') showReportSheet(context, channel);
            },
            itemBuilder: (_) => [
              if (post.isProduct) PopupMenuItem(value: 'fav', child: Text(app.favorites.contains(post.id) ? 'Retirer des favoris' : 'Ajouter aux favoris')),
              PopupMenuItem(value: 'report', child: Text('Signaler')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => Column(children: [
          Expanded(child: Center(child: InteractiveViewer(child: ProductImage(color: post.color, bytes: post.bytes, height: 380)))),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.text.replaceAll('\n', ' '), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, height: 1.3)),
              SizedBox(height: 14),
              Row(children: [
                if (post.reactions.isNotEmpty)
                  GestureDetector(
                    onTap: () => pickReaction(context, post),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(22)),
                      child: Text('${post.reactions.take(4).join(' ')}  ${post.reactionCount}', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () => pickReaction(context, post),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                    child: Icon(Icons.add_reaction_outlined, size: 22),
                  ),
                ),
                Spacer(),
                if (post.isProduct)
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(channel: channel, post: post))),
                    child: Text('Voir le produit'),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    ));
  }
}
