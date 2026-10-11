import 'dart:math';
import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cart_button.dart';
import '../widgets/contact_buttons.dart';
import '../widgets/helpers.dart';
import '../widgets/post_bubble.dart';
import '../widgets/verified_badge.dart';
import 'channel_info_screen.dart';
import 'media_viewer_screen.dart';
import 'product_detail_screen.dart';
import 'publish_product_screen.dart';
import 'reviews_screen.dart';
import 'search_screen.dart';

/// Fil de publications d'une boutique, filtrable par catégorie, avec chargement progressif.
class ChannelFeedScreen extends StatefulWidget {
  final Channel channel;
  const ChannelFeedScreen({super.key, required this.channel});
  @override
  State<ChannelFeedScreen> createState() => _ChannelFeedScreenState();
}

class _ChannelFeedScreenState extends State<ChannelFeedScreen> {
  String? cat;
  int shown = 40;
  final scroll = ScrollController();
  Channel get channel => widget.channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => app.markRead(channel));
  }

  void _go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Future<void> _menu(String v) async {
    switch (v) {
      case 'infos':
        _go(ChannelInfoScreen(channel: channel));
      case 'search':
        _go(SearchScreen(channel: channel));
      case 'contact':
        showModalBottomSheet(
          context: context,
          backgroundColor: C.bubble,
          builder: (_) => SafeArea(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Contacter ${channel.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 14),
            ContactButtons(phone: channel.phone, message: 'Bonjour, je vous contacte depuis Whatstore.'),
          ]))),
        );
      case 'reviews':
        _go(ReviewsScreen(channel: channel));
      case 'share':
        shareLink(context, 's/${channel.id}', message: channel.name);
      case 'media':
        if (await confirmDialog(context, 'Effacer les fichiers médias ?', 'Les fichiers téléchargés de cette boutique seront supprimés de ton téléphone.', ok: 'Effacer', danger: true)) {
          app.clearStorage(channel);
          if (mounted) toast(context, 'Fichiers médias effacés');
        }
      case 'shortcut':
        app.togglePin(channel);
        toast(context, app.pinned.contains(channel.id) ? 'Boutique épinglée en haut de l\'accueil' : 'Raccourci retiré');
      case 'report':
        showReportSheet(context, channel);
      case 'unfollow':
        if (!channel.followed) {
          app.toggleFollow(channel);
        } else if (await confirmDialog(context, 'Ne plus suivre ?', 'Tu ne verras plus ${channel.name} sur ton accueil.', ok: 'Ne plus suivre', danger: true)) {
          app.toggleFollow(channel);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final k = channel.followers >= 1000 ? '${(channel.followers / 1000).round()} K' : '${channel.followers}';
        final rating = app.ratingOf(channel);
        final cats = <String>{for (final p in channel.posts) if (p.category != null) p.category!}.toList();
        if (cat != null && !cats.contains(cat)) cat = null;
        final all = cat == null ? channel.posts : channel.posts.where((p) => p.category == cat).toList();
        final start = max(0, all.length - shown);
        final posts = all.sublist(start);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _go(ChannelInfoScreen(channel: channel)),
              child: Row(children: [
                ChannelAvatar(color: channel.color, name: channel.name, bytes: channel.logo, url: channel.logoUrl, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Align(alignment: Alignment.centerLeft, child: ChannelTitle(channel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
                    Text('$k abonnés${rating != null ? ' · ★ ${rating.toStringAsFixed(1)}' : ''}', style: TextStyle(fontSize: 12.5, color: C.sub)),
                  ]),
                ),
              ]),
            ),
            actions: [
              CartButton(),
              IconButton(
                tooltip: channel.muted ? 'Activer les notifications' : 'Mettre en silencieux',
                icon: Icon(channel.muted ? Icons.notifications_off_outlined : Icons.notifications_none),
                onPressed: () {
                  app.toggleMute(channel);
                  toast(context, channel.muted ? 'Notifications désactivées' : 'Notifications activées');
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert),
                offset: Offset(0, 48),
                onSelected: _menu,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'infos', height: 48, child: Text('Infos de la boutique')),
                  PopupMenuItem(value: 'search', height: 48, child: Text('Rechercher')),
                  if (!channel.mine && channel.phone.isNotEmpty) PopupMenuItem(value: 'contact', height: 48, child: Text('Contacter le vendeur')),
                  PopupMenuItem(value: 'reviews', height: 48, child: Text('Avis')),
                  PopupMenuItem(value: 'share', height: 48, child: Text('Partager')),
                  PopupMenuItem(value: 'media', height: 48, child: Text('Effacer les fichiers médias')),
                  PopupMenuItem(value: 'shortcut', height: 48, child: Text(app.pinned.contains(channel.id) ? 'Retirer le raccourci' : 'Ajouter un raccourci')),
                  if (!channel.mine) PopupMenuItem(value: 'report', height: 48, child: Text('Signaler')),
                  PopupMenuItem(value: 'unfollow', height: 48, child: Text(channel.followed ? 'Ne plus suivre' : 'Suivre')),
                ],
              ),
            ],
          ),
          body: Column(children: [
            if (cats.length > 1)
              SizedBox(
                height: 48,
                child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7), children: [
                  _chip('Tout', cat == null, () => setState(() => cat = null)),
                  for (final c in cats) _chip(c, cat == c, () => setState(() => cat = c)),
                ]),
              ),
            Expanded(
              child: posts.isEmpty
                  ? Center(child: Text(channel.mine ? 'Publie ton premier produit avec le bouton « Publier ».' : 'Aucune publication', style: TextStyle(color: C.sub)))
                  : ListView.builder(
                      controller: scroll,
                      padding: EdgeInsets.only(top: 6, bottom: 90),
                      itemCount: posts.length + (start > 0 ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (start > 0 && i == 0) {
                          return Center(child: TextButton(onPressed: () => setState(() => shown += 40), child: Text('Voir les messages précédents', style: TextStyle(color: C.link))));
                        }
                        final p = posts[i - (start > 0 ? 1 : 0)];
                        return GestureDetector(
                          onLongPress: () => showPostOptions(context, channel, p),
                          child: PostBubble(
                            post: p,
                            channelName: channel.name,
                            onTapMedia: () => _go(MediaViewerScreen(channel: channel, post: p)),
                            onAddToCart: () {
                              if (p.variants.isNotEmpty) {
                                _go(ProductDetailScreen(channel: channel, post: p));
                                return;
                              }
                              toast(context, app.addToCart(channel, p) ? 'Ajouté au panier' : 'Stock limité');
                            },
                          ),
                        );
                      },
                    ),
            ),
          ]),
          floatingActionButton: channel.mine
              ? FloatingActionButton.extended(
                  onPressed: () => _go(PublishProductScreen(channel: channel)),
                  backgroundColor: C.green, foregroundColor: Colors.black,
                  icon: Icon(Icons.add_a_photo_outlined), label: Text('Publier'),
                )
              : FloatingActionButton.small(
                  onPressed: () {
                    if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
                  },
                  backgroundColor: C.bubble, foregroundColor: C.sub, elevation: 2, shape: CircleBorder(),
                  child: Icon(Icons.keyboard_double_arrow_down),
                ),
        );
      },
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label), selected: sel, onSelected: (_) => onTap(), showCheckmark: false,
          backgroundColor: C.chip, selectedColor: C.greenPill,
          side: BorderSide(color: sel ? C.green : Colors.transparent),
          labelStyle: TextStyle(color: sel ? C.green : C.text, fontSize: 13.5),
        ),
      );
}
