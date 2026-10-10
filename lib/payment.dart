/// Couche paiement mobile money. En mode API, remplacé par ApiPaymentService (voir services/services.dart).
class PaymentRequest {
  final String provider, phone, reference;
  final int amount; // FCFA
  const PaymentRequest(this.provider, this.phone, this.amount, this.reference);
}

class PaymentResult {
  final bool ok;
  final String? message;
  const PaymentResult(this.ok, [this.message]);
}

abstract class PaymentService {
  Future<PaymentResult> pay(PaymentRequest r);
  Future<PaymentResult> refund(PaymentRequest r);
}

class MockPaymentService implements PaymentService {
  @override
  Future<PaymentResult> pay(PaymentRequest r) async {
    await Future.delayed(const Duration(seconds: 2));
    return r.phone.length >= 8 ? const PaymentResult(true) : const PaymentResult(false, 'Numéro invalide');
  }

  @override
  Future<PaymentResult> refund(PaymentRequest r) async {
    await Future.delayed(const Duration(seconds: 1));
    return const PaymentResult(true);
  }
}

PaymentService paymentService = MockPaymentService();
