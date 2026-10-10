import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Adresses de livraison enregistrées.
class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  Future<void> _edit(BuildContext context, [Address? a]) async {
    final label = TextEditingController(text: a?.label ?? ''), text = TextEditingController(text: a?.text ?? '');
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text(a == null ? 'Nouvelle adresse' : 'Modifier l\'adresse'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: label, decoration: InputDecoration(labelText: 'Nom (Maison, Travail...)')),
          TextField(controller: text, maxLines: 2, decoration: InputDecoration(labelText: 'Adresse / repères')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Annuler', style: TextStyle(color: C.sub))),
          TextButton(
            onPressed: () {
              if (text.text.trim().isNotEmpty) app.saveAddress(label.text.trim().isEmpty ? 'Adresse' : label.text.trim(), text.text.trim(), a);
              Navigator.pop(d);
            },
            child: Text('Enregistrer', style: TextStyle(color: C.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mes adresses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context), backgroundColor: C.green, foregroundColor: Colors.black, icon: Icon(Icons.add), label: Text('Adresse')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.addresses.isEmpty) return Center(child: Text('Aucune adresse enregistrée', style: TextStyle(color: C.sub)));
          return ListView(children: [
            for (final a in app.addresses)
              ListTile(
                leading: Icon(Icons.place_outlined, color: C.sub),
                title: Text(a.label),
                subtitle: Text(a.text, style: TextStyle(color: C.sub)),
                onTap: () => _edit(context, a),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Supprimer cette adresse ?', a.text, ok: 'Supprimer', danger: true)) app.deleteAddress(a);
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}
