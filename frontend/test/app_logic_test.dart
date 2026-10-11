import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatstore/data.dart';
import 'package:whatstore/models.dart';
import 'package:whatstore/services/launcher.dart';
import 'package:whatstore/state.dart';

Channel _shop() => Channel(id: 't1', name: 'Test', followers: 0, color: Colors.teal, delivers: true, deliveryFee: 1000);
Post _product({int? stock}) => Post(id: 'p1', type: PostType.image, time: '10:00', text: 'x', title: 'Sac', price: 1000, stock: stock);

void main() {
  test('normalizeText supprime accents et majuscules', () {
    expect(normalizeText('Écouteurs ÇA'), 'ecouteurs ca');
  });

  test('normalizePhone ajoute l\'indicatif', () {
    expect(normalizePhone('0197669861'), '2290197669861');
    expect(normalizePhone('+229 01 97 66 98 61'), '2290197669861');
    expect(normalizePhone('00229 0197669861'), '2290197669861');
  });

  test('commission et net d\'une commande', () {
    final c = _shop();
    final o = Order(
      ref: 'R1', lines: [CartLine(c, _product(), 2)], provider: 'MTN MoMo', phone: '0100000000',
      buyerName: 'A', delivery: true, fees: {c.id: 1000},
    );
    expect(o.itemsTotal, 2000);
    expect(o.total, 3000);
    expect(o.commissionFor(c), 100); // 5 % de 2000
    expect(o.netFor(c), 2900);
  });

  test('le panier respecte le stock', () {
    final c = _shop();
    final p = _product(stock: 3);
    app.cart.clear();
    expect(app.addToCart(c, p, 2), true);
    expect(app.addToCart(c, p, 5), false);
    expect(app.cart.first.qty, 3);
    app.cart.clear();
  });

  test('la note moyenne se calcule sur les avis', () {
    final c = _shop();
    app.reviews
      ..clear()
      ..add(Review('1', c.id, 'p1', 'A', 5, ''))
      ..add(Review('2', c.id, 'p1', 'B', 3, ''));
    expect(app.ratingOf(c), 4.0);
    app.reviews.clear();
  });

  test('sérialisation produit aller-retour', () {
    final p = _product(stock: 4)..variants = ['S', 'M'];
    final back = Post.fromJson(p.toJson(NoMediaIO()), NoMediaIO());
    expect(back.title, 'Sac');
    expect(back.stock, 4);
    expect(back.variants, ['S', 'M']);
  });
}
