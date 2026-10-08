import 'package:flutter/material.dart';
import '../brand.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/helpers.dart';

/// Connexion par téléphone + code (simulé : tout code à 6 chiffres est accepté).
/// À brancher sur ton API d'authentification (OTP SMS).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final name = TextEditingController(), phone = TextEditingController(), code = TextEditingController();
  bool codeStep = false;

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label, filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: EdgeInsets.all(24), children: [
          SizedBox(height: 40),
          Center(child: BrandLogo(size: 104)),
          SizedBox(height: 20),
          Center(child: Text(Brand.name, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700))),
          SizedBox(height: 6),
          Center(child: Text(Brand.tagline, textAlign: TextAlign.center, style: TextStyle(color: C.sub, fontSize: 15))),
          SizedBox(height: 36),
          if (!codeStep) ...[
            TextField(controller: name, decoration: _dec('Ton nom')),
            SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: _dec('Numéro de téléphone')),
          ] else ...[
            Text('Code envoyé au ${phone.text}', style: TextStyle(color: C.sub)),
            SizedBox(height: 12),
            TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: _dec('Code à 6 chiffres')),
            TextButton(onPressed: () => toast(context, 'Code renvoyé'), child: Text('Renvoyer le code', style: TextStyle(color: C.green))),
          ],
          SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(52)),
            onPressed: () {
              if (!codeStep) {
                if (name.text.trim().length < 2 || phone.text.replaceAll(RegExp(r'\D'), '').length < 8) {
                  toast(context, 'Renseigne ton nom et un numéro valide');
                  return;
                }
                setState(() => codeStep = true);
              } else {
                if (code.text.length != 6) {
                  toast(context, 'Entre les 6 chiffres');
                  return;
                }
                app.login(name.text.trim(), phone.text.trim());
              }
            },
            child: Text(codeStep ? 'Valider' : 'Recevoir le code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          if (codeStep) TextButton(onPressed: () => setState(() => codeStep = false), child: Text('Modifier le numéro', style: TextStyle(color: C.sub))),
        ]),
      ),
    );
  }
}
