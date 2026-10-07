import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cart_button.dart';
import '../widgets/post_bubble.dart';
import 'channel_info_screen.dart';
import 'media_viewer_screen.dart';
import 'publish_product_screen.dart';
import 'search_screen.dart';

/// Fil de publications d'une chaîne (store), filtrable par catégorie.
class ChannelFeedScreen extends StatefulWidget {
  final Channel channel;
  const ChannelFeedScreen({super.key, required this.channel});
  @override
  State<ChannelFeedScreen> createState() => _ChannelFeedScreenState();
}

class _ChannelFeedScreenState extends State<ChannelFeedScreen> {
  String? cat;
  Channel get channel => widget.channel;

  void _go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final k = channel.followers >= 1000 ? '${(channel.followers / 1000).round()} K' : '${channel.followers}';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _go(ChannelInfoScreen(channel: channel)),
          child: Row(children: [
            ChannelAvatar(color: channel.color, name: channel.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                Text('$k followers', style: const TextStyle(fontSize: 12.5, color: C.sub)),
              ]),
            ),
          ]),
        ),
        actions: [
          const CartButton(),
          const Icon(Icons.notifications_off_outlined),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            offset: const Offset(0, 48),
            onSelected: (v) {
              if (v == 'infos') _go(ChannelInfoScreen(channel: channel));
              if (v == 'search') _go(SearchScreen(channel: channel));
              if (v == 'unfollow') {
                app.toggleFollow(channel);
                Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'infos', height: 48, child: Text('Infos de la chaîne')),
              const PopupMenuItem(value: 'search', height: 48, child: Text('Rechercher')),
              const PopupMenuItem(value: 'share', height: 48, child: Text('Partager')),
              const PopupMenuItem(value: 'media', height: 48, child: Text('Effacer les fichiers médias')),
              const PopupMenuItem(value: 'shortcut', height: 48, child: Text('Ajouter un raccourci')),
              const PopupMenuItem(value: 'report', height: 48, child: Text('Signaler')),
              PopupMenuItem(value: 'unfollow', height: 48, child: Text(channel.followed ? 'Ne plus suivre' : 'Suivre')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final cats = <String>{for (final p in channel.posts) if (p.category != null) p.category!}.toList();
          final posts = cat == null ? channel.posts : channel.posts.where((p) => p.category == cat).toList();
          return Column(children: [
            if (cats.length > 1)
              SizedBox(
                height: 48,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), children: [
                  _chip('Tout', cat == null, () => setState(() => cat = null)),
                  for (final c in cats) _chip(c, cat == c, () => setState(() => cat = c)),
                ]),
              ),
            Expanded(
              child: posts.isEmpty
                  ? const Center(child: Text('Aucune publication', style: TextStyle(color: C.sub)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 6, bottom: 90),
                      itemCount: posts.length,
                      itemBuilder: (_, i) {
                        final p = posts[i];
                        return PostBubble(
                          post: p,
                          channelName: channel.name,
                          onTapMedia: () => _go(MediaViewerScreen(channel: channel, post: p)),
                          onAddToCart: () {
                            app.addToCart(channel, p);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(content: Text('Ajouté au panier'), duration: Duration(seconds: 1)));
                          },
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: channel.mine
          ? FloatingActionButton.extended(
              onPressed: () => _go(PublishProductScreen(channel: channel)),
              backgroundColor: C.green, foregroundColor: Colors.black,
              icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Publier'),
            )
          : FloatingActionButton.small(
              onPressed: () {},
              backgroundColor: C.bubble, foregroundColor: C.sub, elevation: 2, shape: const CircleBorder(),
              child: const Icon(Icons.keyboard_double_arrow_down),
            ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          backgroundColor: C.chip,
          selectedColor: C.greenPill,
          side: BorderSide(color: sel ? C.green : Colors.transparent),
          labelStyle: TextStyle(color: sel ? C.green : C.text, fontSize: 13.5),
        ),
      );
}
