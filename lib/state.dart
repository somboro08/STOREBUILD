import 'package:flutter/material.dart';
import 'data.dart';

class CartLine {
  final Channel channel;
  final Post post;
  int qty;
  CartLine(this.channel, this.post, this.qty);
  int get total => (post.price ?? 0) * qty;
}

class ProductRef {
  final Channel channel;
  final Post post;
  ProductRef(this.channel, this.post);
}

class Order {
  final String ref, provider, phone;
  final List<CartLine> lines;
  final int total;
  final bool delivery;
  Order(this.ref, this.lines, this.total, this.provider, this.phone, this.delivery);
}

/// État global simple (sans dépendance). À remplacer par ton API / Riverpod / Bloc plus tard.
class AppState extends ChangeNotifier {
  final List<Channel> channels = allChannels;
  final List<CartLine> cart = [];
  final List<Order> orders = [];

  List<Channel> get followed => channels.where((c) => c.followed).toList();
  List<Channel> get mine => channels.where((c) => c.mine).toList();

  void toggleFollow(Channel c) {
    c.followed = !c.followed;
    c.followers += c.followed ? 1 : -1;
    notifyListeners();
  }

  Channel createStore({required String name, required String description, required String category, required String zone, required String phone, required Color color}) {
    final c = Channel(
      id: 'u${DateTime.now().microsecondsSinceEpoch}', name: name, description: description, category: category,
      zone: zone, phone: phone, color: color, followers: 0, mine: true, created: _today(),
    );
    channels.insert(0, c);
    notifyListeners();
    return c;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  void publish(Channel c, Post p) {
    c.posts.add(p);
    c.preview = p.title ?? p.text;
    c.time = p.time;
    notifyListeners();
  }

  List<ProductRef> products([Channel? only]) => [
        for (final c in channels)
          if (only == null || c == only)
            for (final p in c.posts)
              if (p.isProduct) ProductRef(c, p),
      ];

  int get cartCount => cart.fold(0, (a, l) => a + l.qty);
  int get cartTotal => cart.fold(0, (a, l) => a + l.total);

  void addToCart(Channel c, Post p, [int qty = 1]) {
    final i = cart.indexWhere((l) => l.post.id == p.id);
    if (i >= 0) {
      cart[i].qty += qty;
    } else {
      cart.add(CartLine(c, p, qty));
    }
    notifyListeners();
  }

  void setQty(CartLine l, int q) {
    if (q <= 0) {
      cart.remove(l);
    } else {
      l.qty = q;
    }
    notifyListeners();
  }

  String newRef() => 'MS${DateTime.now().millisecondsSinceEpoch % 1000000}';

  Order placeOrder({required String ref, required String provider, required String phone, required bool delivery}) {
    final o = Order(ref, List.of(cart), cartTotal, provider, phone, delivery);
    orders.add(o);
    cart.clear();
    notifyListeners();
    return o;
  }
}

final app = AppState();
