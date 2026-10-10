import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'create_store_screen.dart';
import 'store_dashboard_screen.dart';

class MyStoresScreen extends StatelessWidget {
  const MyStoresScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mes boutiques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.mine;
          if (list.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Tu n\'as pas encore de boutique.', style: TextStyle(color: C.sub, fontSize: 16)),
                SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateStoreScreen())),
                  child: Text('Créer ma boutique'),
                ),
              ]),
            );
          }
          return ListView(children: [
            for (final c in list)
              ListTile(
                leading: ChannelAvatar(color: c.color, name: c.name, bytes: c.logo, url: c.logoUrl),
                title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${c.posts.where((p) => p.isProduct).length} produits · ${fmtInt(c.followers)} abonnés · ${app.sellerOrders(c).length} commandes', style: TextStyle(color: C.sub, fontSize: 13)),
                trailing: Icon(Icons.chevron_right, color: C.sub),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDashboardScreen(channel: c))),
              ),
          ]);
        },
      ),
    );
  }
}
