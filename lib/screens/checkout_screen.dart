import 'package:flutter/material.dart';
import '../data.dart';
import '../payment.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';
import 'addresses_screen.dart';
import 'orders_screen.dart';

/// Paiement mobile money (MTN MoMo, Moov Money, Celtiis Cash) avec retrait ou livraison.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final phone = TextEditingController(text: app.user?.phone ?? ''), addr = TextEditingController();
  String provider = 'MTN MoMo';
  bool delivery = false, saveAddr = false, busy = false;

  static const providers = {'MTN MoMo': Color(0xFFFFCC00), 'Moov Money': Color(0xFF0066B3), 'Celtiis Cash': Color(0xFF00A859)};

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label, filled: true, fillColor: C.chip,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  int get fee => delivery ? app.deliveryFeeForCart() : 0;
  int get total => app.cartTotal + fee;

  Future<void> _pay() async {
    if (!_form.currentState!.validate()) return;
    setState(() => busy = true);
    final ref = app.newRef();
    final res = await paymentService.pay(PaymentRequest(provider, phone.text.trim(), total, ref));
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) {
      toast(context, res.message ?? 'Paiement refusé');
      return;
    }
    if (delivery && saveAddr && addr.text.trim().isNotEmpty) app.saveAddress('Adresse ${app.addresses.length + 1}', addr.text.trim());
    final o = app.placeOrder(ref: ref, provider: provider, phone: phone.text.trim(), delivery: delivery, address: addr.text.trim());
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: o)));
  }

  @override
  Widget build(BuildContext context) {
    final canDeliver = app.cartDeliverable;
    return Scaffold(
      appBar: AppBar(title: Text('Paiement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: Form(
        key: _form,
        child: ListView(padding: EdgeInsets.all(16), children: [
          Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          SizedBox(height: 10),
          for (final e in providers.entries)
            Container(
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(12), border: Border.all(color: provider == e.key ? C.green : Colors.transparent, width: 1.5)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: e.value, radius: 16, child: Icon(Icons.phone_android, size: 16, color: Colors.white)),
                title: Text(e.key),
                trailing: Icon(provider == e.key ? Icons.radio_button_checked : Icons.radio_button_off, color: provider == e.key ? C.green : C.sub),
                onTap: () => setState(() => provider = e.key),
              ),
            ),
          SizedBox(height: 8),
          TextFormField(
            controller: phone, keyboardType: TextInputType.phone, decoration: _dec('Numéro $provider'),
            validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? 'Numéro invalide' : null,
          ),
          SizedBox(height: 18),
          Text('Réception', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          RadioListTile<bool>(contentPadding: EdgeInsets.zero, activeColor: C.green, value: false, groupValue: delivery, onChanged: (v) => setState(() => delivery = v!), title: Text('Retrait en boutique')),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero, activeColor: C.green, value: true, groupValue: delivery,
            onChanged: canDeliver ? (v) => setState(() => delivery = v!) : null,
            title: Text('Livraison${canDeliver && app.deliveryFeeForCart() > 0 ? ' (+${fmtInt(app.deliveryFeeForCart())} F)' : ''}'),
            subtitle: canDeliver ? null : Text('Toutes les boutiques du panier doivent proposer la livraison', style: TextStyle(color: C.sub, fontSize: 12.5)),
          ),
          if (delivery) ...[
            if (app.addresses.isNotEmpty)
              Wrap(spacing: 8, children: [
                for (final a in app.addresses) ActionChip(label: Text(a.label), backgroundColor: C.chip, onPressed: () => setState(() => addr.text = a.text)),
              ]),
            SizedBox(height: 8),
            TextFormField(controller: addr, maxLines: 2, decoration: _dec('Adresse de livraison'), validator: (v) => delivery && (v ?? '').trim().isEmpty ? 'Obligatoire' : null),
            CheckboxListTile(contentPadding: EdgeInsets.zero, activeColor: C.green, controlAffinity: ListTileControlAffinity.leading, value: saveAddr, onChanged: (v) => setState(() => saveAddr = v ?? false), title: Text('Enregistrer cette adresse')),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddressesScreen())), child: Text('Gérer mes adresses', style: TextStyle(color: C.link)))),
          ],
          SizedBox(height: 18),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              for (final l in app.cart)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${l.qty} × ${l.post.title}${l.variant.isEmpty ? '' : ' (${l.variant})'}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${fmtInt(l.total)} F'),
                  ]),
                ),
              if (delivery) Padding(padding: EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text('Livraison')), Text(fee == 0 ? 'Gratuite' : '${fmtInt(fee)} F')])),
              Divider(color: C.divider),
              Row(children: [
                Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Text('${fmtInt(total)} FCFA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: C.green)),
              ]),
            ]),
          ),
          SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(52)),
            onPressed: busy ? null : _pay,
            child: busy ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)) : Text('Payer ${fmtInt(total)} FCFA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 40, backgroundColor: C.green, child: Icon(Icons.check, size: 46, color: Colors.black)),
              SizedBox(height: 20),
              Text('Paiement confirmé', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('${fmtInt(order.total)} FCFA via ${order.provider}', style: TextStyle(color: C.sub, fontSize: 15)),
              SizedBox(height: 4),
              Text('Référence : ${order.ref}', style: TextStyle(color: C.sub, fontSize: 15)),
              SizedBox(height: 4),
              Text(order.delivery ? 'Livraison à organiser avec la boutique' : 'Retrait en boutique', style: TextStyle(color: C.sub, fontSize: 15)),
              SizedBox(height: 28),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: Size(220, 48)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order))),
                child: Text('Suivre ma commande'),
              ),
              SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size(220, 48)),
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: Text('Retour aux boutiques'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
