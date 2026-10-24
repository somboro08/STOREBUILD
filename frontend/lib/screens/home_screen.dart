import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cart_button.dart';
import 'channel_feed_screen.dart';
import 'create_store_screen.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'my_stores_screen.dart';
import 'notifications_screen.dart';
import 'publish_product_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';

/// Accueil : stores suivis (chaque chaîne = un store).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Boutiques', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
        actions: [
          IconButton(icon: Icon(Icons.qr_code_scanner), tooltip: 'Scanner un produit', onPressed: () => _go(context, ScanScreen())),
          CartButton(),
          ListenableBuilder(
            listenable: app,
            builder: (_, __) => IconButton(
              tooltip: 'Notifications',
              icon: Badge(isLabelVisible: app.unreadNotices > 0, label: Text('${app.unreadNotices}'), backgroundColor: C.green, textColor: Colors.black, child: Icon(Icons.notifications_none)),
              onPressed: () => _go(context, NotificationsScreen()),
            ),
          ),
          IconButton(icon: Icon(Icons.search), tooltip: 'Rechercher un produit', onPressed: () => _go(context, SearchScreen())),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'store') _go(context, CreateStoreScreen());
              if (v == 'fav') _go(context, FavoritesScreen());
              if (v == 'mine') _go(context, MyStoresScreen());
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'store', child: Text('Créer ma boutique')),
              PopupMenuItem(value: 'mine', child: Text('Mes boutiques')),
              PopupMenuItem(value: 'fav', child: Text('Mes favoris')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.followed;
          return ListView(padding: EdgeInsets.only(bottom: 150), children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Mes boutiques', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _go(context, ExploreScreen()),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(20)),
                    child: Text('Explorer', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
              ]),
            ),
            if (list.isEmpty)
              Padding(padding: EdgeInsets.all(32), child: Text('Tu ne suis aucune boutique. Appuie sur Explorer pour en trouver.', style: TextStyle(color: C.sub))),
            for (final ch in list) _tile(context, ch),
          ]);
        },
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'edit', tooltip: 'Créer ma boutique',
          onPressed: () => _go(context, CreateStoreScreen()),
          backgroundColor: C.bubble, foregroundColor: C.text, elevation: 0,
          child: Icon(Icons.edit),
        ),
        SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'cam', tooltip: 'Publier un produit',
          onPressed: () => _go(context, PublishProductScreen()),
          backgroundColor: C.green, foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.add_a_photo_outlined),
        ),
      ]),

    );
  }

  Widget _tile(BuildContext context, Channel ch) {
    final unread = ch.unread > 0;
    return InkWell(
      onTap: () => _go(context, ChannelFeedScreen(channel: ch)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          ChannelAvatar(color: ch.color, name: ch.name, bytes: ch.logo, url: ch.logoUrl, size: 52),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500)),
              SizedBox(height: 3),
              Row(children: [
                Icon(Icons.image, size: 15, color: C.sub),
                SizedBox(width: 4),
                Expanded(child: Text(ch.preview.isEmpty ? 'Nouvelle boutique' : ch.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.sub, fontSize: 14))),
              ]),
            ]),
          ),
          SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(ch.time, style: TextStyle(fontSize: 12, color: unread ? C.green : C.sub)),
            SizedBox(height: 6),
            if (unread)
              Container(
                constraints: BoxConstraints(minWidth: 22),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(12)),
                child: Text('${ch.unread}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else
              SizedBox(height: 20),
          ]),
        ]),
      ),
    );
  }
}
