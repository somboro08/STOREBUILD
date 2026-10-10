import 'package:flutter/material.dart';
import '../data.dart';
import '../services/deep_link.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import '../widgets/verified_badge.dart';
import 'channel_feed_screen.dart';
import 'create_store_screen.dart';

/// Explorer : toutes les boutiques, suivi en un tap, ouverture d'un lien collé.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String q = '';

  Future<void> _openLink() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Ouvrir un lien'),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'https://whatstore.store/s/...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(
            onPressed: () {
              Navigator.pop(d);
              if (!openLink(ctrl.text) && mounted) toast(context, 'Lien introuvable');
            },
            child: Text('Ouvrir', style: TextStyle(color: C.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Explorer les boutiques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)), actions: [IconButton(icon: Icon(Icons.link), tooltip: 'Ouvrir un lien', onPressed: _openLink)]),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final n = normalizeText(q);
          final list = app.channels.where((c) => normalizeText('${c.name} ${c.category} ${c.zone}').contains(n)).toList();
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
            if (list.isEmpty) Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune boutique trouvée', style: TextStyle(color: C.sub)))),
            for (final c in list)
              ListTile(
                leading: ChannelAvatar(color: c.color, name: c.name, bytes: c.logo, url: c.logoUrl),
                title: ChannelTitle(c, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                subtitle: Text('${c.category.isEmpty ? 'Boutique' : c.category} · ${fmtInt(c.followers)} abonnés', style: TextStyle(color: C.sub)),
                trailing: c.followed
                    ? OutlinedButton(onPressed: () => app.toggleFollow(c), child: Text('Suivie'))
                    : FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black), onPressed: () => app.toggleFollow(c), child: Text('Suivre')),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: c))),
              ),
          ]);
        },
      ),
    );
  }
}
