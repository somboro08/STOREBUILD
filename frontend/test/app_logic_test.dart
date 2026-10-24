import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatstore/data.dart';
import 'package:whatstore/catalog_models.dart';
import 'package:whatstore/models.dart';
import 'package:whatstore/services/csv.dart';
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

  group('catalogue physique', () {
    CatalogItem item({int stock = 5}) => CatalogItem(id: 'i1', channelId: 'cat1', code: 'K7M2QX', name: 'Cahier', stock: stock, lowStock: 3, barcodes: ['6001234567890']);

    setUp(() {
      app.items.clear();
      app.blankCodes.clear();
      app.movements.clear();
    });

    test('codes courts uniques et sans caractères ambigus', () {
      final seen = <String>{};
      for (var i = 0; i < 300; i++) {
        final c = app.newCode('cat1');
        expect(c.length, 6);
        expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(c), true);
        app.blankCodes.add(CatalogCode('cat1', c));
        expect(seen.add(c), true);
      }
    });

    test('mouvements de stock : bornes, alertes et historique', () {
      final it = item();
      app.items.add(it);
      app.moveStock(it, -2, 'vente');
      expect(it.stock, 3);
      expect(it.low, true);
      app.moveStock(it, -10, 'perte');
      expect(it.stock, 0);
      expect(it.out, true);
      expect(app.movements.first.delta, -3); // le stock ne passe jamais sous 0
      app.setStockTo(it, 7);
      expect(it.stock, 7);
      expect(it.availability, 'Disponible');
    });

    test('le stock du catalogue est reflété sur la publication en ligne', () {
      final it = item();
      final post = Post(id: 'pp1', type: PostType.image, time: '10:00', text: 'x', title: 'Cahier', price: 500, stock: 5);
      final ch = Channel(id: 'cat1', name: 'Boutique', followers: 0, color: Colors.teal, mine: true, posts: [post]);
      app.channels.add(ch);
      it.postId = post.id;
      app.items.add(it);
      app.moveStock(it, -5, 'vente');
      expect(post.stock, 0);
      expect(post.sold, true);
      app.moveStock(it, 4, 'entree');
      expect(post.stock, 4);
      expect(post.sold, false);
      app.channels.remove(ch);
    });

    test('résolution des scans : lien, code court, code-barres, étiquette vierge', () {
      final it = item();
      app.items.add(it);
      app.blankCodes.add(CatalogCode('cat1', 'AAAAAA'));
      expect(app.resolveScan('https://whatstore.store/q/cat1/k7m2qx').item?.id, 'i1');
      expect(app.resolveScan('K7M2QX').item?.id, 'i1');
      expect(app.resolveScan('6001234567890').item?.id, 'i1');
      expect(app.resolveScan('AAAAAA').kind, ScanKind.blank);
      expect(app.resolveScan('ZZZZZZ').kind, ScanKind.unknown);
    });

    test('sérialisation du produit aller-retour', () {
      final it = item()..details = [['Format', 'A4']];
      final back = CatalogItem.fromJson(it.toJson(NoMediaIO()), NoMediaIO());
      expect(back.code, 'K7M2QX');
      expect(back.details.first, ['Format', 'A4']);
      expect(back.barcodes, ['6001234567890']);
    });
  });

  group('phase 2 et 3', () {
    CatalogItem item({int stock = 10, int cost = 1000}) => CatalogItem(id: 'p2', channelId: 'cat2', code: 'ABCD23', name: 'Sac', stock: stock, cost: cost, price: 2000);
    Channel shop() => Channel(id: 'cat2', name: 'Boutique', followers: 0, color: Colors.teal, mine: true);

    setUp(() {
      app.items.clear();
      app.sales.clear();
      app.purchases.clear();
      app.reservations.clear();
      app.movements.clear();
    });

    test('vente en caisse : stock retiré puis restitué à l\'annulation', () {
      final it = item();
      app.items.add(it);
      final s = app.createSale(shop(), [SaleLine(it.id, it.title, 3, 2000, 1000)]);
      expect(it.stock, 7);
      expect(s.total, 6000);
      expect(s.profit, 3000);
      app.voidSale(s);
      expect(it.stock, 10);
      expect(s.voided, true);
    });

    test('achat : frais répartis et coût moyen pondéré', () {
      final it = item(stock: 12, cost: 1000);
      app.items.add(it);
      final lines = app.landedLines([PurchaseLine(it.id, 10, 1000)], 2000);
      expect(lines.first.landed, 1200);
      app.savePurchase(shop(), 'Guangzhou', 2000, '', [PurchaseLine(it.id, 10, 1000)]);
      expect(it.stock, 22);
      expect(it.cost, ((12 * 1000 + 10 * 1200) / 22).round());
    });

    test('réservation : stock retiré, annulation le restitue', () {
      final c = shop();
      app.channels.add(c);
      final it = item();
      app.items.add(it);
      final r = app.reserve(it, c, 4, 'Cliente', '0197000000');
      expect(it.stock, 6);
      app.setReservation(r, 'cancelled');
      expect(it.stock, 10);
      app.channels.remove(c);
    });

    test('CSV : guillemets, séparateur ; et montants', () {
      final rows = parseCsv('Nom;Prix\n"Cahier; 100p";"1 500"\nStylo;100\n');
      expect(rows[1][0], 'Cahier; 100p');
      expect(parseAmount(rows[1][1]), 1500);
      expect(parseAmount('1.500'), 1500);
      expect(parseAmount('1500,50'), 1501);
      expect(mapHeader('Désignation'), 'name');
      expect(mapHeader('Prix d\'achat'), 'cost');
      expect(mapHeader('Code-barres'), 'barcode');
    });
  });
}
