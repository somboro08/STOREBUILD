import 'package:flutter/material.dart';
import '../services/launcher.dart';
import '../theme.dart';
import 'helpers.dart';

/// Boutons Appeler / WhatsApp vers une boutique.
class ContactButtons extends StatelessWidget {
  final String phone;
  final String message;
  const ContactButtons({super.key, required this.phone, this.message = ''});

  @override
  Widget build(BuildContext context) {
    if (phone.trim().isEmpty) {
      return Text('Numéro du vendeur non renseigné', style: TextStyle(color: C.sub, fontSize: 13));
    }
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            if (!await callPhone(phone) && context.mounted) toast(context, 'Impossible de lancer l\'appel');
          },
          icon: Icon(Icons.call, size: 18),
          label: Text('Appeler'),
        ),
      ),
      SizedBox(width: 10),
      Expanded(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black),
          onPressed: () async {
            if (!await openWhatsApp(phone, message) && context.mounted) toast(context, 'WhatsApp indisponible');
          },
          icon: Icon(Icons.chat_bubble_outline, size: 18),
          label: Text('WhatsApp'),
        ),
      ),
    ]);
  }
}
