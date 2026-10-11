import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brand.dart';
import 'data.dart';
import 'models.dart';
import 'payment.dart';
import 'services/local_store.dart';
import 'services/services.dart';
import 'theme.dart';

export 'models.dart';

/// État global + persistance locale + file de synchronisation (voir docs/API_CONTRACT.md).
class AppState extends ChangeNotifier {
  final List<Channel> channels = allChannels;
  final List<CartLine> cart = [];
  final List<Order> orders = [];
  final List<Review> reviews = [];
  final List<Address> addresses = [];
  final List<Payout> payouts = [];
  final List<AppNotice> notices = [];
  final List<Report> reports = [];
  final List<SyncOp> queue = [];
  final List<String> searchHistory = [];
  final Set<String> favorites = {}, pinned = {};
  AppUser? user;
  bool notifications = true, onboarded = false, online = true;
  ThemeMode themeMode = ThemeMode.dark;
  String? pendingLink;

  SharedPreferences? _prefs;
  LocalStore? _store;
  Timer? _saveTimer;
  bool _flushing = false;

  // ------------------------------------------------------------ démarrage / persistance
  Future<void> loadPrefs() async {
    await Services.init();
    final p = _prefs = await SharedPreferences.getInstance();
    onboarded = p.getBool('onboarded') ?? false;
    notifications = p.getBool('notifications') ?? true;
    themeMode = ThemeMode.values[min(2, max(0, p.getInt('theme') ?? ThemeMode.dark.index))];
    final n = p.getString('user_name'), ph = p.getString('user_phone');
    if (n != null && ph != null) user = AppUser(n, ph);
    _applyBrightness();
    try {
      final s = _store = await LocalStore.open();
      final snap = s.readJson();
      if (snap != null && snap['demo'] == Brand.demoData) _applySnapshot(snap, s);
    } catch (_) {}
    try {
      online = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
      Connectivity().onConnectivityChanged.listen((r) => setOnline(!r.contains(ConnectivityResult.none)));
    } catch (_) {}
    if (Services.remote) Future.microtask(() async {
      await flush();
      await pull();
    });
  }

  Map<String, dynamic> _snapshot(MediaIO io) => {
        'v': 1,
        'demo': Brand.demoData,
        'channels': [for (final c in channels) c.toJson(io)],
        'cart': [for (final l in cart) l.toJson()],
        'orders': [for (final o in orders) o.toJson()],
        'reviews': [for (final r in reviews) r.toJson()],
        'addresses': [for (final a in addresses) a.toJson()],
        'payouts': [for (final x in payouts) x.toJson()],
        'notices': [for (final x in notices) x.toJson()],
        'reports': [for (final x in reports) x.toJson()],
        'queue': [for (final q in queue) q.toJson()],
        'favorites': favorites.toList(),
        'pinned': pinned.toList(),
        'search': searchHistory,
      };

  List<Map<String, dynamic>> _list(dynamic v) => [for (final x in (v as List? ?? [])) Map<String, dynamic>.from(x)];

  void _applySnapshot(Map<String, dynamic> j, MediaIO io) {
    // Seules les clés présentes sont remplacées (un snapshot serveur peut être partiel).
    bool has(String k) => j[k] != null;
    if (has('channels')) {
      channels
        ..clear()
        ..addAll(_list(j['channels']).map((c) => Channel.fromJson(c, io)));
    }
    Channel? find(String id) => channelById(id);
    if (has('cart')) {
      cart
        ..clear()
        ..addAll(_list(j['cart']).map((x) => CartLine.fromJson(x, find)).whereType<CartLine>());
    }
    if (has('orders')) {
      orders
        ..clear()
        ..addAll(_list(j['orders']).map((x) => Order.fromJson(x, find)));
    }
    if (has('reviews')) reviews..clear()..addAll(_list(j['reviews']).map(Review.fromJson));
    if (has('addresses')) addresses..clear()..addAll(_list(j['addresses']).map(Address.fromJson));
    if (has('payouts')) payouts..clear()..addAll(_list(j['payouts']).map(Payout.fromJson));
    if (has('notices')) notices..clear()..addAll(_list(j['notices']).map(AppNotice.fromJson));
    if (has('reports')) reports..clear()..addAll(_list(j['reports']).map(Report.fromJson));
    if (has('queue')) queue..clear()..addAll(_list(j['queue']).map(SyncOp.fromJson));
    if (has('favorites')) favorites..clear()..addAll(List<String>.from(j['favorites']));
    if (has('pinned')) pinned..clear()..addAll(List<String>.from(j['pinned']));
    if (has('search')) searchHistory..clear()..addAll(List<String>.from(j['search']));
  }

  void _scheduleSave() {
    if (_store == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      try {
        _store!.writeJson(_snapshot(_store!));
      } catch (_) {}
    });
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSave();
  }

  // ------------------------------------------------------------ synchronisation
  int get pending => queue.length;

  void _log(String type, Map<String, dynamic> payload) {
    queue.add(SyncOp('${DateTime.now().microsecondsSinceEpoch}', type, payload));
    Future.microtask(flush);
  }

  void setOnline(bool v) {
    if (online == v) return;
    online = v;
    notifyListeners();
    if (v) flush();
  }

  Future<void> flush() async {
    if (_flushing || !online || queue.isEmpty) return;
    _flushing = true;
    try {
      while (queue.isNotEmpty && online) {
        final op = queue.first;
        await _prepare(op);
        if (!await Services.sync.push(op)) break;
        queue.remove(op);
      }
    } finally {
      _flushing = false;
    }
    notifyListeners();
  }

  /// Envoie les médias avant la synchro d'un produit / d'une boutique et met les URLs dans l'opération.
  Future<void> _prepare(SyncOp op) async {
    if (!Services.remote) return;
    if (op.type.startsWith('post.') && op.payload['postId'] != null) {
      final p = productById(op.payload['postId'])?.post ?? _postById(op.payload['postId']);
      if (p == null) return;
      if (p.bytes != null && p.imageUrl == null) p.imageUrl = await Services.media.upload(bytes: p.bytes, kind: 'post');
      for (var i = p.extraUrls.length; i < p.extra.length; i++) {
        final u = await Services.media.upload(bytes: p.extra[i], kind: 'post');
        if (u == null) break;
        p.extraUrls.add(u);
      }
      if (p.videoPath != null && p.videoUrl == null) p.videoUrl = await Services.media.upload(path: p.videoPath, kind: 'video');
      op.payload['entity'] = p.toJson(NoMediaIO());
    }
    if (op.type.startsWith('store.') && op.payload['entity'] != null) {
      final c = channelById(op.payload['entity']['id']);
      if (c == null) return;
      if (c.logo != null && c.logoUrl == null) c.logoUrl = await Services.media.upload(bytes: c.logo, kind: 'logo');
      op.payload['entity'] = c.toJson(NoMediaIO(), withPosts: false);
    }
  }

  Post? _postById(String id) {
    for (final c in channels) {
      for (final p in c.posts) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  Future<void> pull() async {
    if (!online || _store == null) return;
    final snap = await Services.sync.pull();
    if (snap == null) return;
    _applySnapshot(snap, _store!);
    notifyListeners();
  }

  // ------------------------------------------------------------ préférences & thème
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

  void setNotifications(bool v) {
    notifications = v;
    _prefs?.setBool('notifications', v);
    notifyListeners();
  }

  // ------------------------------------------------------------ compte
  Future<void> requestCode(String phone) => Services.auth.requestCode(phone);

  Future<void> loginWithCode(String name, String phone, String code) async {
    final u = await Services.auth.verifyCode(phone, code, name);
    login(u.name, u.phone);
    if (Services.remote) Future.microtask(pull);
  }

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
    _log('account.update', {'name': name, 'phone': phone});
    notifyListeners();
  }

  Future<void> changePhone(String phone, String code) async {
    final u = await Services.auth.changePhone(phone, code);
    user = AppUser(user?.name ?? '', u.phone);
    _prefs?.setString('user_phone', u.phone);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await Services.auth.deleteAccount();
    final name = user?.name;
    channels.removeWhere((c) => c.mine);
    reviews.removeWhere((r) => r.author == name);
    for (final l in [orders, cart, addresses, payouts, notices, reports, queue, searchHistory]) {
      l.clear();
    }
    favorites.clear();
    pinned.clear();
    user = null;
    _prefs?.remove('user_name');
    _prefs?.remove('user_phone');
    notifyListeners();
  }

  bool get isAdmin => user != null && Brand.adminPhones.contains(user!.phone);

  // ------------------------------------------------------------ boutiques
  Channel? channelById(String id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  Channel? channelOf(Post p) {
    for (final c in channels) {
      if (c.posts.contains(p)) return c;
    }
    return null;
  }

  ProductRef? productById(String id) {
    for (final c in channels) {
      for (final p in c.posts) {
        if (p.id == id && p.isProduct) return ProductRef(c, p);
      }
    }
    return null;
  }

  List<Channel> get followed {
    final l = channels.where((c) => c.followed).toList();
    l.sort((a, b) => (pinned.contains(b.id) ? 1 : 0) - (pinned.contains(a.id) ? 1 : 0));
    return l;
  }

  List<Channel> get mine => channels.where((c) => c.mine).toList();

  void toggleFollow(Channel c) {
    c.followed = !c.followed;
    c.followers = max(0, c.followers + (c.followed ? 1 : -1));
    if (!c.followed) pinned.remove(c.id);
    _log('store.follow', {'channelId': c.id, 'followed': c.followed});
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

  void markRead(Channel c) {
    if (c.unread == 0) return;
    c.unread = 0;
    notifyListeners();
  }

  void clearStorage(Channel c) {
    c.storageMo = 0;
    notifyListeners();
  }

  Channel createStore({
    required String name, required String description, required String category, required String zone,
    required String phone, required Color color, Uint8List? logo, bool delivers = false, int deliveryFee = 0,
  }) {
    final n = DateTime.now();
    final c = Channel(
      id: 'u${n.microsecondsSinceEpoch}', name: name, description: description, category: category, zone: zone,
      phone: phone, color: color, followers: 0, mine: true, logo: logo, delivers: delivers, deliveryFee: deliveryFee,
      ownerPhone: user?.phone,
      created: '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}',
    );
    channels.insert(0, c);
    _log('store.create', {'entity': c.toJson(NoMediaIO(), withPosts: false)});
    notifyListeners();
    return c;
  }

  void updateStore(
    Channel c, {
    required String name, required String description, required String category, required String zone,
    required String phone, required Color color, Uint8List? logo, bool delivers = false, int deliveryFee = 0,
  }) {
    c.name = name;
    c.description = description;
    c.category = category;
    c.zone = zone;
    c.phone = phone;
    c.color = color;
    if (logo != null) {
      c.logo = logo;
      c.logoUrl = null;
    }
    c.delivers = delivers;
    c.deliveryFee = deliveryFee;
    _log('store.update', {'entity': c.toJson(NoMediaIO(), withPosts: false)});
    notifyListeners();
  }

  void setVerified(Channel c, bool v) {
    c.verified = v;
    _log('store.verify', {'channelId': c.id, 'verified': v});
    notifyListeners();
  }

  void report(Channel c, String reason) {
    reports.add(Report(c.id, reason, user?.name ?? ''));
    _log('report.create', {'channelId': c.id, 'reason': reason});
    notifyListeners();
  }

  // ------------------------------------------------------------ publications / produits
  void _importVideo(Post p) {
    final s = _store;
    if (s == null || p.videoPath == null || p.videoPath!.startsWith(s.root.path)) return;
    try {
      p.videoPath = s.importFile(p.id, p.videoPath!) ?? p.videoPath;
    } catch (_) {}
  }

  void publish(Channel c, Post p) {
    _importVideo(p);
    c.posts.add(p);
    c.preview = p.title ?? (p.text.isEmpty ? 'Nouvelle publication' : p.text);
    c.time = p.time;
    _log('post.create', {'channelId': c.id, 'postId': p.id, 'entity': p.toJson(NoMediaIO())});
    notifyListeners();
  }

  void updatePost(
    Post p, {
    String? title, int? price, String? category, String? text, Uint8List? bytes,
    List<Uint8List>? extra, int? stock, List<String>? variants, String? videoPath,
  }) {
    if (title != null) p.title = title;
    if (price != null) p.price = price;
    if (category != null) p.category = category;
    if (text != null) p.text = text;
    if (bytes != null && !identical(bytes, p.bytes)) {
      p.bytes = bytes;
      p.imageUrl = null;
    }
    if (extra != null) {
      p.extra = extra;
      p.extraUrls = [];
    }
    p.stock = stock;
    if (variants != null) p.variants = variants;
    if (videoPath != null && videoPath != p.videoPath) {
      p.videoPath = videoPath;
      p.videoUrl = null;
      _importVideo(p);
    }
    if (p.stock != null && p.stock! > 0 && p.sold) p.sold = false;
    final c = channelOf(p);
    _log('post.update', {'channelId': c?.id, 'postId': p.id, 'entity': p.toJson(NoMediaIO())});
    notifyListeners();
  }

  void toggleSold(Post p) {
    p.sold = !p.sold;
    _log('post.update', {'channelId': channelOf(p)?.id, 'postId': p.id, 'entity': p.toJson(NoMediaIO())});
    notifyListeners();
  }

  void deletePost(Channel c, Post p) {
    c.posts.remove(p);
    cart.removeWhere((l) => l.post == p);
    favorites.remove(p.id);
    c.preview = c.posts.isEmpty ? '' : (c.posts.last.title ?? c.posts.last.text);
    _log('post.delete', {'channelId': c.id, 'postId': p.id});
    notifyListeners();
  }

  void toggleFavorite(Post p) {
    favorites.contains(p.id) ? favorites.remove(p.id) : favorites.add(p.id);
    _log('favorite.set', {'postId': p.id, 'value': favorites.contains(p.id)});
    notifyListeners();
  }

  void react(Post p, String e) {
    if (p.myReaction == e) {
      p.myReaction = null;
      p.reactionCount = max(0, p.reactionCount - 1);
    } else {
      if (p.myReaction == null) p.reactionCount++;
      p.myReaction = e;
      if (!p.reactions.contains(e)) p.reactions.insert(0, e);
    }
    _log('post.react', {'channelId': channelOf(p)?.id, 'postId': p.id, 'emoji': p.myReaction});
    notifyListeners();
  }

  List<ProductRef> products([Channel? only]) => [
        for (final c in channels)
          if (only == null || c == only)
            for (final p in c.posts)
              if (p.isProduct) ProductRef(c, p),
      ];

  // ------------------------------------------------------------ recherche
  void addSearch(String q) {
    final t = q.trim();
    if (t.length < 2) return;
    searchHistory.removeWhere((x) => x == t);
    searchHistory.insert(0, t);
    if (searchHistory.length > 8) searchHistory.removeLast();
    notifyListeners();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------ panier
  int get cartCount => cart.fold(0, (a, l) => a + l.qty);
  int get cartTotal => cart.fold(0, (a, l) => a + l.total);

  /// Retourne false si le stock a limité la quantité ajoutée.
  bool addToCart(Channel c, Post p, [int qty = 1, String variant = '']) {
    final cap = p.stock ?? 9999;
    final i = cart.indexWhere((l) => l.key == '${p.id}|$variant');
    final cur = i >= 0 ? cart[i].qty : 0;
    final want = min(cap, cur + qty);
    if (want <= cur) return false;
    if (i >= 0) {
      cart[i].qty = want;
    } else {
      cart.add(CartLine(c, p, want, variant));
    }
    notifyListeners();
    return want == cur + qty;
  }

  void setQty(CartLine l, int q) {
    if (q <= 0) {
      cart.remove(l);
    } else {
      l.qty = min(q, l.post.stock ?? 9999);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ adresses
  Address saveAddress(String label, String text, [Address? existing]) {
    if (existing != null) {
      existing.label = label;
      existing.text = text;
      _log('address.save', {'entity': existing.toJson()});
      notifyListeners();
      return existing;
    }
    final a = Address('a${DateTime.now().microsecondsSinceEpoch}', label, text);
    addresses.add(a);
    _log('address.save', {'entity': a.toJson()});
    notifyListeners();
    return a;
  }

  void deleteAddress(Address a) {
    addresses.remove(a);
    _log('address.delete', {'id': a.id});
    notifyListeners();
  }

  // ------------------------------------------------------------ commandes
  String newRef() => 'WS${DateTime.now().millisecondsSinceEpoch % 1000000}';

  bool get cartDeliverable => cart.isNotEmpty && cart.every((l) => l.channel.delivers);

  int deliveryFeeForCart() => {for (final l in cart) l.channel}.fold(0, (a, c) => a + c.deliveryFee);

  void _notice(String title, String body) {
    notices.insert(0, AppNotice('n${DateTime.now().microsecondsSinceEpoch}', title, body));
    if (notices.length > 100) notices.removeLast();
  }

  int get unreadNotices => notices.where((n) => !n.read).length;

  void readAllNotices() {
    for (final n in notices) {
      n.read = true;
    }
    notifyListeners();
  }

  Order placeOrder({required String ref, required String provider, required String phone, required bool delivery, String address = ''}) {
    final fees = <String, int>{};
    if (delivery) {
      for (final c in {for (final l in cart) l.channel}) {
        fees[c.id] = c.deliveryFee;
      }
    }
    final o = Order(ref: ref, lines: List.of(cart), provider: provider, phone: phone, buyerName: user?.name ?? '', address: address, delivery: delivery, fees: fees);
    for (final l in o.lines) {
      final p = l.post;
      if (p.stock != null) {
        p.stock = max(0, p.stock! - l.qty);
        if (p.stock == 0) p.sold = true;
      }
    }
    orders.insert(0, o);
    cart.clear();
    _notice('Commande ${o.ref} payée', '${fmtInt(o.total)} FCFA via $provider');
    for (final c in o.channels) {
      if (c.mine) _notice('Nouvelle commande ${o.ref}', '${o.buyerName} · ${fmtInt(o.totalFor(c))} FCFA');
    }
    _log('order.create', {'entity': o.toJson()});
    notifyListeners();
    return o;
  }

  void setStatus(Order o, OrderStatus s) {
    o.status = s;
    _notice('Commande ${o.ref}', 'Statut : ${s.label}');
    _log('order.status', {'ref': o.ref, 'status': s.index, 'refunded': o.refunded});
    notifyListeners();
  }

  Future<void> cancelOrder(Order o) async {
    if (o.status == OrderStatus.cancelled) return;
    o.status = OrderStatus.cancelled;
    for (final l in o.lines) {
      final p = l.post;
      if (p.stock != null) {
        p.stock = p.stock! + l.qty;
        p.sold = false;
      }
    }
    _notice('Commande ${o.ref} annulée', 'Remboursement en cours');
    notifyListeners();
    final r = await paymentService.refund(PaymentRequest(o.provider, o.phone, o.total, o.ref));
    o.refunded = r.ok;
    _notice(r.ok ? 'Remboursement effectué' : 'Remboursement en attente', 'Commande ${o.ref} · ${fmtInt(o.total)} FCFA');
    _log('order.status', {'ref': o.ref, 'status': o.status.index, 'refunded': o.refunded});
    notifyListeners();
  }

  List<Order> sellerOrders(Channel c) => orders.where((o) => o.lines.any((l) => l.channel == c)).toList();

  // ------------------------------------------------------------ avis
  bool canReview(Order o, CartLine l) => o.status == OrderStatus.delivered && !o.reviewed.contains(l.post.id);

  void addReview(Order o, CartLine l, int rating, String text) {
    final r = Review('r${DateTime.now().microsecondsSinceEpoch}', l.channel.id, l.post.id, user?.name ?? '', rating, text.trim());
    reviews.insert(0, r);
    o.reviewed.add(l.post.id);
    _log('review.create', {'entity': r.toJson()});
    notifyListeners();
  }

  List<Review> reviewsOf(Channel c, {String? postId}) =>
      reviews.where((r) => r.channelId == c.id && (postId == null || r.postId == postId)).toList();

  double? ratingOf(Channel c, {String? postId}) {
    final l = reviewsOf(c, postId: postId);
    if (l.isEmpty) return null;
    return l.fold<int>(0, (a, r) => a + r.rating) / l.length;
  }

  // ------------------------------------------------------------ revenus vendeur
  int earned(Channel c) => orders.where((o) => o.status == OrderStatus.delivered).fold(0, (a, o) => a + o.netFor(c));
  int pendingEarnings(Channel c) => orders.where((o) => o.active).fold(0, (a, o) => a + o.netFor(c));
  int grossSales(Channel c) => orders.where((o) => o.status == OrderStatus.delivered).fold(0, (a, o) => a + o.totalFor(c));
  int commissions(Channel c) => orders.where((o) => o.status == OrderStatus.delivered).fold(0, (a, o) => a + o.commissionFor(c));
  int paidOut(Channel c) => payouts.where((p) => p.channelId == c.id).fold(0, (a, p) => a + p.amount);
  int balance(Channel c) => earned(c) - paidOut(c);

  String? requestPayout(Channel c, int amount, String phone) {
    if (amount < Brand.minPayout) return 'Minimum ${fmtInt(Brand.minPayout)} FCFA';
    if (amount > balance(c)) return 'Solde insuffisant';
    final p = Payout('p${DateTime.now().microsecondsSinceEpoch}', c.id, amount, phone);
    payouts.insert(0, p);
    _notice('Retrait demandé', '${fmtInt(amount)} FCFA vers $phone');
    _log('payout.request', {'entity': p.toJson()});
    notifyListeners();
    return null;
  }
}

final app = AppState();
