import 'package:flutter/material.dart';
import '../data.dart';
import '../services/services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Équipe de la boutique : gérants, vendeurs / caissiers, magasiniers. L'invité se connecte avec son numéro.
class TeamScreen extends StatelessWidget {
  final Channel channel;
  const TeamScreen({super.key, required this.channel});

  Future<void> _invite(BuildContext context) async {
    final phone = TextEditingController(), name = TextEditingController();
    var role = 'cashier';
    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          backgroundColor: C.bubble,
          title: Text('Ajouter un membre'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: 'Nom')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Numéro de téléphone')),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(value: role, dropdownColor: C.menu, decoration: InputDecoration(labelText: 'Rôle'), items: [for (final e in memberRoles.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => set(() => role = v!)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
            TextButton(
              onPressed: () {
                if (phone.text.replaceAll(RegExp(r'\D'), '').length < 8) return;
                app.inviteMember(channel, phone.text.trim(), name.text, role);
                Navigator.pop(d);
              },
              child: Text('Ajouter', style: TextStyle(color: C.green)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Équipe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _invite(context), backgroundColor: C.green, foregroundColor: Colors.black, icon: Icon(Icons.person_add_alt), label: Text('Ajouter')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.membersOf(channel);
          return ListView(padding: EdgeInsets.only(bottom: 90), children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Gérant : tout sauf équipe et retraits. Vendeur / caissier : caisse, consultation du catalogue, réservations. Magasinier : catalogue, stock et inventaire (sans voir les prix d\'achat).${Services.remote ? '' : '\n\nLes membres se connectent avec leur numéro : cela fonctionne quand l\'application est connectée au serveur.'}',
                style: TextStyle(color: C.sub, fontSize: 13, height: 1.4),
              ),
            ),
            if (list.isEmpty) Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Aucun membre pour le moment', style: TextStyle(color: C.sub)))),
            for (final m in list)
              ListTile(
                leading: CircleAvatar(backgroundColor: C.greenPill, child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: TextStyle(color: C.green, fontWeight: FontWeight.w700))),
                title: Text(m.name.isEmpty ? '+${m.phone}' : m.name),
                subtitle: Text('${memberRoles[m.role] ?? m.role} · +${m.phone}', style: TextStyle(color: C.sub)),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Retirer ${m.name.isEmpty ? 'ce membre' : m.name} ?', 'Il n\'aura plus accès à la boutique.', ok: 'Retirer', danger: true)) app.removeMember(channel, m);
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}
