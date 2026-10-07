import 'package:flutter/material.dart';
import '../data.dart';
import '../payment.dart';
import '../state.dart';
import '../theme.dart';

/// Paiement mobile money (MTN MoMo, Moov Money, Celtiis Cash).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final phone = TextEditingController(), addr = TextEditingController();
  String provider = 'MTN MoMo';
  bool delivery = false;
  bool busy = false;

  static const providers = {
    'MTN MoMo': Color(0xFFFFCC00),
    'Moov Money': Color(0xFF0066B3),
    'Celtiis Cash': Color(0xFF00A859),
  };

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label, filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Future<void> _pay() async {
    if (!_form.currentState!.validate()) return;
    setState(() => busy = true);
    final ref = app.newRef();
    final res = await paymentService.pay(PaymentRequest(provider, phone.text.trim(), app.cartTotal, ref));
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message ?? 'Paiement refusé')));
      return;
    }
    final o = app.placeOrder(ref: ref, provider: provider, phone: phone.text.trim(), delivery: delivery);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: o)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          for (final e in providers.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: C.chip, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: provider == e.key ? C.green : Colors.transparent, width: 1.5),
              ),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: e.value, radius: 16, child: const Icon(Icons.phone_android, size: 16, color: Colors.white)),
                title: Text(e.key),
                trailing: Icon(provider == e.key ? Icons.radio_button_checked : Icons.radio_button_off, color: provider == e.key ? C.green : C.sub),
                onTap: () => setState(() => provider = e.key),
              ),
            ),
          const SizedBox(height: 8),
          TextFormField(
            controller: phone, keyboardType: TextInputType.phone, decoration: _dec('Numéro $provider'),
            validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? 'Numéro invalide' : null,
          ),
          const SizedBox(height: 18),
          const Text('Réception', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          RadioListTile<bool>(contentPadding: EdgeInsets.zero, activeColor: C.green, value: false, groupValue: delivery, onChanged: (v) => setState(() => delivery = v!), title: const Text('Retrait en boutique')),
          RadioListTile<bool>(contentPadding: EdgeInsets.zero, activeColor: C.green, value: true, groupValue: delivery, onChanged: (v) => setState(() => delivery = v!), title: const Text('Livraison')),
          if (delivery)
            TextFormField(controller: addr, decoration: _dec('Adresse de livraison'), validator: (v) => delivery && (v ?? '').trim().isEmpty ? 'Obligatoire' : null),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              for (final l in app.cart)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${l.qty} × ${l.post.title}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${fmtInt(l.total)} F'),
                  ]),
                ),
              const Divider(color: C.divider),
              Row(children: [
                const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Text('${fmtInt(app.cartTotal)} FCFA', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: C.green)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(52)),
            onPressed: busy ? null : _pay,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                : Text('Payer ${fmtInt(app.cartTotal)} FCFA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final Order order;
  const OrderSuccessScreen({super.key, required this.order});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(radius: 40, backgroundColor: C.green, child: Icon(Icons.check, size: 46, color: Colors.black)),
              const SizedBox(height: 20),
              const Text('Paiement confirmé', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('${fmtInt(order.total)} FCFA via ${order.provider}', style: const TextStyle(color: C.sub, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Référence : ${order.ref}', style: const TextStyle(color: C.sub, fontSize: 15)),
              const SizedBox(height: 4),
              Text(order.delivery ? 'Livraison à organiser avec le store' : 'Retrait en boutique', style: const TextStyle(color: C.sub, fontSize: 15)),
              const SizedBox(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: const Size(220, 48)),
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Retour aux stores'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
