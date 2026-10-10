import 'package:flutter/material.dart';
import '../brand.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/helpers.dart';
import 'legal_screen.dart';

/// Connexion par téléphone + code (via AuthService : local ou API).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final name = TextEditingController(), phone = TextEditingController(), code = TextEditingController();
  bool codeStep = false, busy = false;

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label, filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Future<void> _next() async {
    setState(() => busy = true);
    try {
      if (!codeStep) {
        if (name.text.trim().length < 2 || phone.text.replaceAll(RegExp(r'\D'), '').length < 8) throw Exception('Renseigne ton nom et un numéro valide');
        await app.requestCode(phone.text.trim());
        setState(() => codeStep = true);
      } else {
        if (code.text.length != 6) throw Exception('Entre les 6 chiffres');
        await app.loginWithCode(name.text.trim(), phone.text.trim(), code.text.trim());
      }
    } catch (e) {
      if (mounted) toast(context, '$e'.replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => busy = false);
  }

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
            TextButton(onPressed: () async { await app.requestCode(phone.text.trim()); if (context.mounted) toast(context, 'Code renvoyé'); }, child: Text('Renvoyer le code', style: TextStyle(color: C.green))),
          ],
          SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(52)),
            onPressed: busy ? null : _next,
            child: busy ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)) : Text(codeStep ? 'Valider' : 'Recevoir le code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          if (codeStep) TextButton(onPressed: () => setState(() => codeStep = false), child: Text('Modifier le numéro', style: TextStyle(color: C.sub))),
          SizedBox(height: 18),
          Wrap(alignment: WrapAlignment.center, children: [
            Text('En continuant, tu acceptes nos ', style: TextStyle(color: C.sub, fontSize: 12.5)),
            GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen())), child: Text('conditions', style: TextStyle(color: C.link, fontSize: 12.5))),
            Text(' et notre ', style: TextStyle(color: C.sub, fontSize: 12.5)),
            GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(privacy: true))), child: Text('politique de confidentialité', style: TextStyle(color: C.link, fontSize: 12.5))),
          ]),
        ]),
      ),
    );
  }
}
