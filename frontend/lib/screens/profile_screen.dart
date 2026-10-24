import 'package:flutter/material.dart';
import '../brand.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import 'addresses_screen.dart';
import 'admin_screen.dart';
import 'create_store_screen.dart';
import 'favorites_screen.dart';
import 'legal_screen.dart';
import 'my_stores_screen.dart';
import 'notifications_screen.dart';
import 'reservations_screen.dart';

/// Profil : compte, boutiques, adresses, favoris, réglages, légal, suppression du compte.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: app.user!.name);
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Modifier mon nom'),
        content: TextField(controller: name, decoration: InputDecoration(labelText: 'Nom')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(
            onPressed: () {
              if (name.text.trim().length >= 2) app.updateUser(name.text.trim(), app.user!.phone);
              Navigator.pop(d);
            },
            child: Text('Enregistrer', style: TextStyle(color: C.green)),
          ),
        ],
      ),
    );
  }

  /// Changement de numéro avec vérification par code.
  Future<void> _changePhone(BuildContext context) async {
    final phone = TextEditingController(), code = TextEditingController();
    var sent = false, busy = false;
    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          backgroundColor: C.bubble,
          title: Text('Changer de numéro'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: phone, enabled: !sent, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Nouveau numéro')),
            if (sent) TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: 'Code reçu par SMS')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      set(() => busy = true);
                      try {
                        if (!sent) {
                          if (phone.text.replaceAll(RegExp(r'\D'), '').length < 8) throw Exception('Numéro invalide');
                          await app.requestCode(phone.text.trim());
                          set(() => sent = true);
                        } else {
                          await app.changePhone(phone.text.trim(), code.text.trim());
                          if (d.mounted) Navigator.pop(d);
                          if (context.mounted) toast(context, 'Numéro mis à jour');
                        }
                      } catch (e) {
                        if (context.mounted) toast(context, '$e'.replaceFirst('Exception: ', ''));
                      }
                      if (d.mounted) set(() => busy = false);
                    },
              child: Text(sent ? 'Valider' : 'Envoyer le code', style: TextStyle(color: C.green)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    if (!await confirmDialog(context, 'Supprimer mon compte ?', 'Tes boutiques, commandes, adresses et données personnelles seront effacées. Cette action est définitive.', ok: 'Continuer', danger: true)) return;
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text('Confirmation'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tape SUPPRIMER pour confirmer.', style: TextStyle(color: C.sub)),
          TextField(controller: ctrl),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(onPressed: () => Navigator.pop(d, ctrl.text.trim().toUpperCase() == 'SUPPRIMER'), child: Text('Supprimer', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    await app.deleteAccount();
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
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(onPressed: () => _edit(context), child: Text('Modifier le nom', style: TextStyle(color: C.green))),
              TextButton(onPressed: () => _changePhone(context), child: Text('Changer de numéro', style: TextStyle(color: C.green))),
            ]),
            Divider(color: C.divider, thickness: 8),
            ListTile(leading: Icon(Icons.storefront_outlined, color: C.sub), title: Text('Mes boutiques'), subtitle: Text(app.mine.isEmpty ? 'Aucune boutique' : '${app.mine.length} boutique(s)', style: TextStyle(color: C.sub)), onTap: () => _go(context, MyStoresScreen())),
            ListTile(leading: Icon(Icons.add_business_outlined, color: C.sub), title: Text('Créer une boutique'), onTap: () => _go(context, CreateStoreScreen())),
            ListTile(leading: Icon(Icons.favorite_border, color: C.sub), title: Text('Mes favoris'), trailing: Text('${app.favorites.length}', style: TextStyle(color: C.sub)), onTap: () => _go(context, FavoritesScreen())),
            ListTile(leading: Icon(Icons.event_available_outlined, color: C.sub), title: Text('Mes réservations'), trailing: Text('${app.reservations.where((r) => r.mine && r.active).length}', style: TextStyle(color: C.sub)), onTap: () => _go(context, ReservationsScreen())),
            ListTile(leading: Icon(Icons.place_outlined, color: C.sub), title: Text('Mes adresses'), trailing: Text('${app.addresses.length}', style: TextStyle(color: C.sub)), onTap: () => _go(context, AddressesScreen())),
            ListTile(
              leading: Badge(isLabelVisible: app.unreadNotices > 0, label: Text('${app.unreadNotices}'), backgroundColor: C.green, textColor: Colors.black, child: Icon(Icons.notifications_none, color: C.sub)),
              title: Text('Notifications'),
              onTap: () => _go(context, NotificationsScreen()),
            ),
            if (app.isAdmin) ListTile(leading: Icon(Icons.admin_panel_settings_outlined, color: C.link), title: Text('Administration'), onTap: () => _go(context, AdminScreen())),
            Divider(color: C.divider, thickness: 8),
            ListTile(leading: Icon(Icons.brightness_6_outlined, color: C.sub), title: Text('Apparence'), subtitle: Text({ThemeMode.dark: 'Sombre', ThemeMode.light: 'Clair', ThemeMode.system: 'Automatique'}[app.themeMode]!, style: TextStyle(color: C.sub)), onTap: () => _theme(context)),
            SwitchListTile(
              secondary: Icon(Icons.notifications_active_outlined, color: C.sub),
              title: Text('Alertes'),
              subtitle: Text('Commandes et nouveautés des boutiques', style: TextStyle(color: C.sub)),
              value: app.notifications,
              activeColor: C.green,
              onChanged: app.setNotifications,
            ),
            ListTile(leading: Icon(Icons.help_outline, color: C.sub), title: Text('Aide'), onTap: () => infoDialog(context, 'Aide', 'Whatstore : les paiements se font par mobile money. En cas de problème avec une commande, contacte la boutique depuis la commande. Fais attention aux faux comptes : signale-les depuis le menu de la boutique.\n\nSupport : ${Brand.supportEmail}')),
            ListTile(leading: Icon(Icons.description_outlined, color: C.sub), title: Text('Conditions d\'utilisation'), onTap: () => _go(context, LegalScreen())),
            ListTile(leading: Icon(Icons.privacy_tip_outlined, color: C.sub), title: Text('Politique de confidentialité'), onTap: () => _go(context, LegalScreen(privacy: true))),
            Divider(color: C.divider, thickness: 8),
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
            ListTile(leading: Icon(Icons.delete_forever_outlined, color: Colors.redAccent), title: Text('Supprimer mon compte', style: TextStyle(color: Colors.redAccent)), onTap: () => _deleteAccount(context)),
            SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}
