import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cart_button.dart';
import 'channel_feed_screen.dart';
import 'create_store_screen.dart';
import 'explore_screen.dart';
import 'publish_product_screen.dart';
import 'search_screen.dart';

/// Accueil : stores suivis (chaque chaîne = un store).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actus', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
        actions: [
          const CartButton(),
          IconButton(icon: const Icon(Icons.search), tooltip: 'Rechercher un produit', onPressed: () => _go(context, const SearchScreen())),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.followed;
          return ListView(padding: const EdgeInsets.only(bottom: 150), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Chaînes', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _go(context, const ExploreScreen()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Explorer', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
              ]),
            ),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Text('Tu ne suis aucun store. Appuie sur Explorer pour en trouver.', style: TextStyle(color: C.sub))),
            for (final ch in list) _tile(context, ch),
          ]);
        },
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'edit', tooltip: 'Créer mon store',
          onPressed: () => _go(context, const CreateStoreScreen()),
          backgroundColor: C.bubble, foregroundColor: C.text, elevation: 0,
          child: const Icon(Icons.edit),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'cam', tooltip: 'Publier un produit',
          onPressed: () => _go(context, const PublishProductScreen()),
          backgroundColor: C.green, foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_a_photo_outlined),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: C.greenPill,
        height: 68,
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(icon: Badge(label: Text('23'), backgroundColor: C.green, textColor: Colors.black, child: Icon(Icons.chat_outlined)), label: 'Discussions'),
          NavigationDestination(icon: Icon(Icons.donut_large_outlined), selectedIcon: Icon(Icons.donut_large), label: 'Actus'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Communautés'),
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Appels'),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Channel ch) {
    final unread = ch.unread > 0;
    return InkWell(
      onTap: () => _go(context, ChannelFeedScreen(channel: ch)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          ChannelAvatar(color: ch.color, name: ch.name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.image, size: 15, color: C.sub),
                const SizedBox(width: 4),
                Expanded(child: Text(ch.preview.isEmpty ? 'Nouveau store' : ch.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.sub, fontSize: 14))),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(ch.time, style: TextStyle(fontSize: 12, color: unread ? C.green : C.sub)),
            const SizedBox(height: 6),
            if (unread)
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(12)),
                child: Text('${ch.unread}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else
              const SizedBox(height: 20),
          ]),
        ]),
      ),
    );
  }
}
