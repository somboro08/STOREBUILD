import 'package:flutter/material.dart';
import '../state.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          if (app.online && app.pending == 0) return SizedBox.shrink();
          final text = app.online ? 'Synchronisation en cours · ${app.pending} action(s) en attente' : 'Hors ligne · tes actions sont enregistrées sur ton téléphone';
          return Container(
            width: double.infinity,
            color: app.online ? Color(0xFF1565C0) : Color(0xFF8D6E00),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SafeArea(bottom: false, child: Text(text, style: TextStyle(color: Colors.white, fontSize: 12.5))),
          );
        },
      );
}
