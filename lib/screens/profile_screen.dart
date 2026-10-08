import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'create_store_screen.dart';
import 'favorites_screen.dart';
import 'my_stores_screen.dart';

/// Profil : compte, mes stores, favoris, réglages, déconnexion.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: app.user!.name), phone = TextEditingController(text: app.user!.phone);
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Modifier mon profil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: 'Nom')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Téléphone')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(
            onPressed: () {
              if (name.text.trim().length >= 2) app.updateUser(name.text.trim(), phone.text.trim());
              Navigator.pop(d);
            },
            child: Text('Enregistrer', style: TextStyle(color: C.green)),
          ),
        ],
      ),
    );
  }

  void _theme(BuildContext context) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Apparence'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in {ThemeMode.dark: 'Sombre', ThemeMode.light: 'Clair', ThemeMode.system: 'Automatique (système)'}.entries)
            RadioListTile<ThemeMode>(
              contentPadding: EdgeInsets.zero,
              value: e.key,
              groupValue: app.themeMode,
              activeColor: C.green,
              title: Text(e.value),
              onChanged: (v) {
                Navigator.pop(d);
                app.setThemeMode(v!);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final u = app.user;
          if (u == null) return SizedBox();
          return ListView(children: [
            SizedBox(height: 10),
            Center(child: ChannelAvatar(color: C.greenPill, name: u.name, size: 88)),
            SizedBox(height: 12),
            Center(child: Text(u.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
            Center(child: Text(u.phone, style: TextStyle(color: C.sub))),
            Center(child: TextButton(onPressed: () => _edit(context), child: Text('Modifier', style: TextStyle(color: C.green)))),
            Divider(color: C.divider, thickness: 8),
            ListTile(leading: Icon(Icons.storefront_outlined, color: C.sub), title: Text('Mes boutiques'), subtitle: Text(app.mine.isEmpty ? 'Aucune boutique' : '${app.mine.length} boutique(s)', style: TextStyle(color: C.sub)), onTap: () => _go(context, MyStoresScreen())),
            ListTile(leading: Icon(Icons.add_business_outlined, color: C.sub), title: Text('Créer une boutique'), onTap: () => _go(context, CreateStoreScreen())),
            ListTile(leading: Icon(Icons.favorite_border, color: C.sub), title: Text('Mes favoris'), trailing: Text('${app.favorites.length}', style: TextStyle(color: C.sub)), onTap: () => _go(context, FavoritesScreen())),
            Divider(color: C.divider, thickness: 8),
            ListTile(
              leading: Icon(Icons.brightness_6_outlined, color: C.sub),
              title: Text('Apparence'),
              subtitle: Text({ThemeMode.dark: 'Sombre', ThemeMode.light: 'Clair', ThemeMode.system: 'Automatique'}[app.themeMode]!, style: TextStyle(color: C.sub)),
              onTap: () => _theme(context),
            ),
            SwitchListTile(
              secondary: Icon(Icons.notifications_none, color: C.sub),
              title: Text('Notifications'),
              subtitle: Text('Commandes et nouveautés des boutiques', style: TextStyle(color: C.sub)),
              value: app.notifications,
              activeColor: C.green,
              onChanged: app.setNotifications,
            ),
            ListTile(
              leading: Icon(Icons.help_outline, color: C.sub),
              title: Text('Aide et conditions'),
              onTap: () => infoDialog(context, 'Aide', 'Whatstore : les paiements se font par mobile money. En cas de problème avec une commande, contacte la boutique depuis sa page. Fais attention aux faux comptes : signale-les depuis le menu de la boutique.'),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.redAccent),
              title: Text('Se déconnecter', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                if (await confirmDialog(context, 'Se déconnecter ?', 'Ton panier sera vidé.', ok: 'Déconnexion', danger: true)) {
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  app.logout();
                }
              },
            ),
            SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}
