import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'channel_feed_screen.dart';
import 'create_store_screen.dart';

/// Explorer : tous les stores, avec suivi en un tap.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Explorer les boutiques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.channels.where((c) => '${c.name} ${c.category} ${c.zone}'.toLowerCase().contains(q.toLowerCase())).toList();
          return ListView(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(
                  hintText: 'Nom, catégorie ou zone',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: C.chip,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                ),
              ),
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: C.green, foregroundColor: Colors.black, child: Icon(Icons.storefront)),
              title: Text('Créer ma boutique', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Vends tes produits à tes abonnés', style: TextStyle(color: C.sub)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStoreScreen())),
            ),
            for (final c in list)
              ListTile(
                leading: ChannelAvatar(color: c.color, name: c.name),
                title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${c.category.isEmpty ? 'Boutique' : c.category} · ${fmtInt(c.followers)} abonnés', style: TextStyle(color: C.sub)),
                trailing: c.followed
                    ? OutlinedButton(onPressed: () => app.toggleFollow(c), child: Text('Suivie'))
                    : FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black),
                        onPressed: () => app.toggleFollow(c),
                        child: Text('Suivre'),
                      ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: c))),
              ),
          ]);
        },
      ),
    );
  }
}
