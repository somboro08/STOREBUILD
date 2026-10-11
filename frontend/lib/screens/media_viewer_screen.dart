import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import '../widgets/video_view.dart';
import 'product_detail_screen.dart';

/// Visionneuse plein écran : images (glisser), vidéo, enregistrement dans la galerie, partage.
class MediaViewerScreen extends StatefulWidget {
  final Channel channel;
  final Post post;
  const MediaViewerScreen({super.key, required this.channel, required this.post});
  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  int page = 0;
  Post get post => widget.post;
  Channel get channel => widget.channel;

  Future<void> _save() async {
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      if (post.hasVideo && post.videoPath != null) {
        await Gal.putVideo(post.videoPath!);
      } else if (post.allImages.isNotEmpty) {
        await Gal.putImageBytes(post.allImages[min(page, post.allImages.length - 1)]);
      } else {
        if (mounted) toast(context, 'Aucun fichier à enregistrer');
        return;
      }
      if (mounted) toast(context, 'Enregistré dans la galerie');
    } catch (_) {
      if (mounted) toast(context, 'Enregistrement impossible');
    }
  }

  Widget _body() {
    if (post.hasVideo) return VideoView(path: post.videoPath, url: post.videoUrl);
    final imgs = post.allImages;
    if (imgs.isEmpty) {
      final urls = [if (post.imageUrl != null) post.imageUrl!, ...post.extraUrls];
      if (urls.isEmpty) return Center(child: ProductImage(color: post.color, height: 380));
      return PageView(onPageChanged: (i) => setState(() => page = i), children: [for (final u in urls) InteractiveViewer(child: Image.network(u, fit: BoxFit.contain))]);
    }
    return PageView(
      onPageChanged: (i) => setState(() => page = i),
      children: [for (final b in imgs) InteractiveViewer(child: Image.memory(b, fit: BoxFit.contain))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = post.hasVideo ? 1 : (post.allImages.isNotEmpty ? post.allImages.length : post.imageCount);
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(channel.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            Text('Aujourd\'hui, ${post.time}${count > 1 ? ' · ${page + 1}/$count' : ''}', style: TextStyle(fontSize: 13, color: C.sub)),
          ]),
          actions: [
            IconButton(icon: Icon(Icons.file_download_outlined), tooltip: 'Enregistrer', onPressed: _save),
            IconButton(icon: Icon(Icons.shortcut), tooltip: 'Partager', onPressed: () => shareLink(context, 'p/${post.id}', message: post.title)),
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
            Expanded(child: _body()),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.text.replaceAll('\n', ' '), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, height: 1.3, color: Colors.white)),
                SizedBox(height: 14),
                Row(children: [
                  if (post.reactions.isNotEmpty)
                    GestureDetector(
                      onTap: () => pickReaction(context, post),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(22)),
                        child: Text('${post.reactions.take(4).join(' ')}  ${post.reactionCount}', style: TextStyle(fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => pickReaction(context, post),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                      child: Icon(Icons.add_reaction_outlined, size: 22, color: Colors.white),
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
      ),
    );
  }
}
