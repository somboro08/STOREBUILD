import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'channel_feed_screen.dart';

/// Création d'un store (= une chaîne dont l'utilisateur est le vendeur).
class CreateStoreScreen extends StatefulWidget {
  final Channel? editing;
  const CreateStoreScreen({super.key, this.editing});
  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController(), desc = TextEditingController(), zone = TextEditingController(), phone = TextEditingController();
  String? cat;
  Color color = Color(0xFF00897B);
  static const palette = [Color(0xFF00897B), Color(0xFF1565C0), Color(0xFFAD1457), Color(0xFFEF6C00), Color(0xFF6A1B9A), Color(0xFF455A64)];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      name.text = e.name;
      desc.text = e.description;
      zone.text = e.zone;
      phone.text = e.phone;
      cat = categories.contains(e.category) ? e.category : null;
      color = e.color;
    }
  }

  InputDecoration _dec(String label, [String? hint]) => InputDecoration(
        labelText: label, hintText: hint,
        filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? 'Créer ma boutique' : 'Modifier ma boutique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Form(
        key: _form,
        child: ListView(padding: EdgeInsets.all(16), children: [
          Center(child: ValueListenableBuilder(valueListenable: name, builder: (_, __, ___) => ChannelAvatar(color: color, name: name.text, size: 96))),
          SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final c in palette)
              GestureDetector(
                onTap: () => setState(() => color = c),
                child: Container(
                  width: 34, height: 34, margin: EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2.5)),
                ),
              ),
          ]),
          SizedBox(height: 20),
          TextFormField(controller: name, decoration: _dec('Nom de la boutique'), validator: (v) => (v ?? '').trim().length < 3 ? 'Au moins 3 caractères' : null),
          SizedBox(height: 12),
          TextFormField(controller: desc, maxLines: 3, decoration: _dec('Description', 'Ce que tu vends, tes horaires...')),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: cat, decoration: _dec('Catégorie principale'), dropdownColor: C.menu,
            items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => cat = v),
            validator: (v) => v == null ? 'Choisis une catégorie' : null,
          ),
          SizedBox(height: 12),
          TextFormField(controller: zone, decoration: _dec('Zone / boutiques', 'Ex : Calavi, Cotonou Dantokpa')),
          SizedBox(height: 12),
          TextFormField(
            controller: phone, keyboardType: TextInputType.phone, decoration: _dec('Téléphone de la boutique'),
            validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? 'Numéro invalide' : null,
          ),
          SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(50)),
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              if (widget.editing != null) {
                app.updateStore(widget.editing!, name: name.text.trim(), description: desc.text.trim(), category: cat!, zone: zone.text.trim(), phone: phone.text.trim(), color: color);
                Navigator.pop(context);
                return;
              }
              final c = app.createStore(name: name.text.trim(), description: desc.text.trim(), category: cat!, zone: zone.text.trim(), phone: phone.text.trim(), color: color);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: c)));
            },
            child: Text(widget.editing == null ? 'Créer la boutique' : 'Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
