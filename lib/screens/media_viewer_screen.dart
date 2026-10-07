import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'product_detail_screen.dart';

/// Visionneuse plein écran d'un média de la chaîne.
class MediaViewerScreen extends StatelessWidget {
  final Channel channel;
  final Post post;
  const MediaViewerScreen({super.key, required this.channel, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(channel.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Text('13 septembre, ${post.time}', style: const TextStyle(fontSize: 13, color: C.sub)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.file_download_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.shortcut), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        Expanded(child: Center(child: ProductImage(color: post.color, bytes: post.bytes, height: 380))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: post.text.replaceAll('\n', ' '), style: const TextStyle(fontSize: 16, height: 1.3)),
              const TextSpan(text: '… Voir plus', style: TextStyle(color: C.link, fontWeight: FontWeight.w700, fontSize: 16)),
            ]), maxLines: 3, overflow: TextOverflow.clip),
            const SizedBox(height: 14),
            Row(children: [
              if (post.reactions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(22)),
                  child: Text('${post.reactions.take(4).join(' ')}  ${post.reactionCount}', style: const TextStyle(fontSize: 15)),
                ),
              const SizedBox(width: 10),
              Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                child: const Icon(Icons.add_reaction_outlined, size: 22),
              ),
              const Spacer(),
              if (post.price != null)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(channel: channel, post: post))),
                  child: const Text('Voir le produit'),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
