import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'channel_feed_screen.dart';

/// Création d'un store (= une chaîne dont l'utilisateur est le vendeur).
class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});
  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController(), desc = TextEditingController(), zone = TextEditingController(), phone = TextEditingController();
  String? cat;
  Color color = const Color(0xFF00897B);
  static const palette = [Color(0xFF00897B), Color(0xFF1565C0), Color(0xFFAD1457), Color(0xFFEF6C00), Color(0xFF6A1B9A), Color(0xFF455A64)];

  InputDecoration _dec(String label, [String? hint]) => InputDecoration(
        labelText: label, hintText: hint,
        filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon store', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: ValueListenableBuilder(valueListenable: name, builder: (_, __, ___) => ChannelAvatar(color: color, name: name.text, size: 96))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final c in palette)
              GestureDetector(
                onTap: () => setState(() => color = c),
                child: Container(
                  width: 34, height: 34, margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2.5)),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          TextFormField(controller: name, decoration: _dec('Nom du store'), validator: (v) => (v ?? '').trim().length < 3 ? 'Au moins 3 caractères' : null),
          const SizedBox(height: 12),
          TextFormField(controller: desc, maxLines: 3, decoration: _dec('Description', 'Ce que tu vends, tes horaires...')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: cat, decoration: _dec('Catégorie principale'), dropdownColor: const Color(0xFF111B21),
            items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => cat = v),
            validator: (v) => v == null ? 'Choisis une catégorie' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(controller: zone, decoration: _dec('Zone / boutiques', 'Ex : Calavi, Cotonou Dantokpa')),
          const SizedBox(height: 12),
          TextFormField(
            controller: phone, keyboardType: TextInputType.phone, decoration: _dec('Téléphone du store'),
            validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? 'Numéro invalide' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50)),
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              final c = app.createStore(name: name.text.trim(), description: desc.text.trim(), category: cat!, zone: zone.text.trim(), phone: phone.text.trim(), color: color);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: c)));
            },
            child: const Text('Créer le store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
