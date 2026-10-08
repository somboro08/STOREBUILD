import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'theme.dart';

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

enum OrderStatus { paid, confirmed, ready, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => const {
        OrderStatus.paid: 'Payée',
        OrderStatus.confirmed: 'Confirmée',
        OrderStatus.ready: 'Prête',
        OrderStatus.delivered: 'Livrée',
        OrderStatus.cancelled: 'Annulée',
      }[this]!;
  OrderStatus? get next => const {
        OrderStatus.paid: OrderStatus.confirmed,
        OrderStatus.confirmed: OrderStatus.ready,
        OrderStatus.ready: OrderStatus.delivered,
      }[this];
  String get action => const {
        OrderStatus.paid: 'Confirmer',
        OrderStatus.confirmed: 'Marquer prête',
        OrderStatus.ready: 'Marquer livrée',
      }[this] ?? '';
  Color get color => const {
        OrderStatus.paid: Color(0xFFFFB300),
        OrderStatus.confirmed: Color(0xFF53BDEB),
        OrderStatus.ready: Color(0xFFAB47BC),
        OrderStatus.delivered: Color(0xFF25D366),
        OrderStatus.cancelled: Color(0xFFEF5350),
      }[this]!;
}

class AppUser {
  String name, phone;
  AppUser(this.name, this.phone);
}

class Order {
  final String ref, provider, phone, buyerName, address;
  final List<CartLine> lines;
  final int total;
  final bool delivery;
  final DateTime date;
  OrderStatus status = OrderStatus.paid;
  Order(this.ref, this.lines, this.total, this.provider, this.phone, this.delivery, this.buyerName, this.address) : date = DateTime.now();
  int totalFor(Channel c) => lines.where((l) => l.channel == c).fold(0, (a, l) => a + l.total);
  bool get active => status != OrderStatus.delivered && status != OrderStatus.cancelled;
}

/// État global simple (sans dépendance). À remplacer par ton API / Riverpod / Bloc plus tard.
class AppState extends ChangeNotifier {
  final List<Channel> channels = allChannels;
  final List<CartLine> cart = [];
  final List<Order> orders = [];
  final Set<String> favorites = {}, pinned = {};
  final List<String> reports = [];
  AppUser? user;
  bool notifications = true;
  bool onboarded = false;
  ThemeMode themeMode = ThemeMode.dark;
  SharedPreferences? _prefs;

  /// Charge les préférences locales (thème, onboarding, session). Appelé au démarrage.
  Future<void> loadPrefs() async {
    final p = _prefs = await SharedPreferences.getInstance();
    onboarded = p.getBool('onboarded') ?? false;
    notifications = p.getBool('notifications') ?? true;
    themeMode = ThemeMode.values[(p.getInt('theme') ?? ThemeMode.dark.index).clamp(0, 2)];
    final n = p.getString('user_name'), ph = p.getString('user_phone');
    if (n != null && ph != null) user = AppUser(n, ph);
    _applyBrightness();
  }

  void _applyBrightness() {
    final sys = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    C.light = themeMode == ThemeMode.light || (themeMode == ThemeMode.system && sys == Brightness.light);
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _applyBrightness();
    _prefs?.setInt('theme', m.index);
    notifyListeners();
    rebuildApp();
  }

  void finishOnboarding() {
    onboarded = true;
    _prefs?.setBool('onboarded', true);
    notifyListeners();
  }

  // ---- session
  void login(String name, String phone) {
    user = AppUser(name, phone);
    _prefs?.setString('user_name', name);
    _prefs?.setString('user_phone', phone);
    notifyListeners();
  }

  void logout() {
    user = null;
    _prefs?.remove('user_name');
    _prefs?.remove('user_phone');
    cart.clear();
    notifyListeners();
  }

  void updateUser(String name, String phone) {
    user = AppUser(name, phone);
    _prefs?.setString('user_name', name);
    _prefs?.setString('user_phone', phone);
    notifyListeners();
  }

  void setNotifications(bool v) {
    notifications = v;
    _prefs?.setBool('notifications', v);
    notifyListeners();
  }

  // ---- stores
  List<Channel> get followed {
    final l = channels.where((c) => c.followed).toList();
    l.sort((a, b) => (pinned.contains(b.id) ? 1 : 0) - (pinned.contains(a.id) ? 1 : 0));
    return l;
  }

  List<Channel> get mine => channels.where((c) => c.mine).toList();

  void toggleFollow(Channel c) {
    c.followed = !c.followed;
    c.followers += c.followed ? 1 : -1;
    if (!c.followed) pinned.remove(c.id);
    notifyListeners();
  }

  void toggleMute(Channel c) {
    c.muted = !c.muted;
    notifyListeners();
  }

  void togglePin(Channel c) {
    pinned.contains(c.id) ? pinned.remove(c.id) : pinned.add(c.id);
    notifyListeners();
  }

  void clearStorage(Channel c) {
    c.storageMo = 0;
    notifyListeners();
  }

  void report(Channel c, String reason) {
    reports.add('${c.id}:$reason');
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

  void updateStore(Channel c, {required String name, required String description, required String category, required String zone, required String phone, required Color color}) {
    c.name = name;
    c.description = description;
    c.category = category;
    c.zone = zone;
    c.phone = phone;
    c.color = color;
    notifyListeners();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  // ---- produits / publications
  void publish(Channel c, Post p) {
    c.posts.add(p);
    c.preview = p.title ?? p.text;
    c.time = p.time;
    notifyListeners();
  }

  void updatePost(Post p, {required String title, required int price, required String category, required String text, dynamic bytes}) {
    p.title = title;
    p.price = price;
    p.category = category;
    p.text = text;
    if (bytes != null) p.bytes = bytes;
    notifyListeners();
  }

  void toggleSold(Post p) {
    p.sold = !p.sold;
    notifyListeners();
  }

  void deletePost(Channel c, Post p) {
    c.posts.remove(p);
    cart.removeWhere((l) => l.post == p);
    favorites.remove(p.id);
    if (c.posts.isEmpty) {
      c.preview = '';
    } else {
      c.preview = c.posts.last.title ?? c.posts.last.text;
    }
    notifyListeners();
  }

  void toggleFavorite(Post p) {
    favorites.contains(p.id) ? favorites.remove(p.id) : favorites.add(p.id);
    notifyListeners();
  }

  void react(Post p, String e) {
    if (p.myReaction == e) {
      p.myReaction = null;
      p.reactionCount = (p.reactionCount - 1).clamp(0, 1 << 30);
    } else {
      if (p.myReaction == null) p.reactionCount++;
      p.myReaction = e;
      if (!p.reactions.contains(e)) p.reactions.insert(0, e);
    }
    notifyListeners();
  }

  List<ProductRef> products([Channel? only]) => [
        for (final c in channels)
          if (only == null || c == only)
            for (final p in c.posts)
              if (p.isProduct) ProductRef(c, p),
      ];

  // ---- panier
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

  // ---- commandes
  String newRef() => 'MS${DateTime.now().millisecondsSinceEpoch % 1000000}';

  Order placeOrder({required String ref, required String provider, required String phone, required bool delivery, String address = ''}) {
    final o = Order(ref, List.of(cart), cartTotal, provider, phone, delivery, user?.name ?? '', address);
    orders.insert(0, o);
    cart.clear();
    notifyListeners();
    return o;
  }

  List<Order> sellerOrders(Channel c) => orders.where((o) => o.lines.any((l) => l.channel == c)).toList();

  void setStatus(Order o, OrderStatus s) {
    o.status = s;
    notifyListeners();
  }
}

final app = AppState();
