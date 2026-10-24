import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brand.dart';
import 'catalog_models.dart';
import 'data.dart';
import 'models.dart';
import 'payment.dart';
import 'services/image_embed.dart';
import 'services/launcher.dart';
import 'services/local_store.dart';
import 'services/services.dart';
import 'theme.dart';

export 'catalog_models.dart';
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
  final List<CatalogGroup> groups = [];
  final List<CatalogItem> items = [];
  final List<StockMovement> movements = [];
  final List<CatalogCode> blankCodes = [];
  final List<Sale> sales = [];
  final List<Purchase> purchases = [];
  final List<Reservation> reservations = [];
  final List<Member> members = [];
  final List<DemandTerm> demand = [];
  final Set<String> alertItems = {};
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
    expireReservations();
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
        'groups': [for (final x in groups) x.toJson()],
        'items': [for (final x in items) x.toJson(io)],
        'movements': [for (final x in movements) x.toJson()],
        'blankCodes': [for (final x in blankCodes) x.toJson()],
        'sales': [for (final x in sales) x.toJson()],
        'purchases': [for (final x in purchases) x.toJson()],
        'reservations': [for (final x in reservations) x.toJson()],
        'members': [for (final x in members) x.toJson()],
        'demand': [for (final x in demand) x.toJson()],
        'alerts': alertItems.toList(),
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
    if (has('groups')) groups..clear()..addAll(_list(j['groups']).map(CatalogGroup.fromJson));
    if (has('items')) items..clear()..addAll(_list(j['items']).map((x) => CatalogItem.fromJson(x, io)));
    if (has('movements')) movements..clear()..addAll(_list(j['movements']).map(StockMovement.fromJson));
    if (has('blankCodes')) blankCodes..clear()..addAll(_list(j['blankCodes']).map(CatalogCode.fromJson));
    if (has('sales')) sales..clear()..addAll(_list(j['sales']).map(Sale.fromJson));
    if (has('purchases')) purchases..clear()..addAll(_list(j['purchases']).map(Purchase.fromJson));
    if (has('reservations')) reservations..clear()..addAll(_list(j['reservations']).map(Reservation.fromJson));
    if (has('members')) members..clear()..addAll(_list(j['members']).map(Member.fromJson));
    if (has('demand')) demand..clear()..addAll(_list(j['demand']).map(DemandTerm.fromJson));
    if (has('alerts')) alertItems..clear()..addAll(List<String>.from(j['alerts']));
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

  void log(String type, Map<String, dynamic> payload) {
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
    if (op.type == 'catalog.item.save' && op.payload['entity'] != null) {
      final it = itemById(op.payload['entity']['id']);
      if (it == null) return;
      for (var i = it.imageUrls.length; i < it.images.length; i++) {
        final u = await Services.media.upload(bytes: it.images[i], kind: 'post');
        if (u == null) break;
        it.imageUrls.add(u);
      }
      op.payload['entity'] = it.toJson(NoMediaIO());
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
    log('account.update', {'name': name, 'phone': phone});
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
    final mineIds = channels.where((c) => c.mine).map((c) => c.id).toSet();
    items.removeWhere((i) => mineIds.contains(i.channelId));
    groups.removeWhere((g) => mineIds.contains(g.channelId));
    movements.removeWhere((m) => mineIds.contains(m.channelId));
    blankCodes.removeWhere((b) => mineIds.contains(b.channelId));
    sales.removeWhere((x) => mineIds.contains(x.channelId));
    purchases.removeWhere((x) => mineIds.contains(x.channelId));
    reservations.clear();
    members.removeWhere((x) => mineIds.contains(x.channelId));
    demand.removeWhere((x) => mineIds.contains(x.channelId));
    alertItems.clear();
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
    log('store.follow', {'channelId': c.id, 'followed': c.followed});
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
    log('store.create', {'entity': c.toJson(NoMediaIO(), withPosts: false)});
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
    log('store.update', {'entity': c.toJson(NoMediaIO(), withPosts: false)});
    notifyListeners();
  }

  void setVerified(Channel c, bool v) {
    c.verified = v;
    log('store.verify', {'channelId': c.id, 'verified': v});
    notifyListeners();
  }

  void report(Channel c, String reason) {
    reports.add(Report(c.id, reason, user?.name ?? ''));
    log('report.create', {'channelId': c.id, 'reason': reason});
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
    log('post.create', {'channelId': c.id, 'postId': p.id, 'entity': p.toJson(NoMediaIO())});
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
    if (itemByPost(p.id) == null) p.stock = stock; // stock géré par le catalogue si le produit y est lié
    if (variants != null) p.variants = variants;
    if (videoPath != null && videoPath != p.videoPath) {
      p.videoPath = videoPath;
      p.videoUrl = null;
      _importVideo(p);
    }
    if (p.stock != null && p.stock! > 0 && p.sold) p.sold = false;
    final c = channelOf(p);
    log('post.update', {'channelId': c?.id, 'postId': p.id, 'entity': p.toJson(NoMediaIO())});
    notifyListeners();
  }

  void toggleSold(Post p) {
    p.sold = !p.sold;
    log('post.update', {'channelId': channelOf(p)?.id, 'postId': p.id, 'entity': p.toJson(NoMediaIO())});
    notifyListeners();
  }

  void deletePost(Channel c, Post p) {
    c.posts.remove(p);
    cart.removeWhere((l) => l.post == p);
    favorites.remove(p.id);
    c.preview = c.posts.isEmpty ? '' : (c.posts.last.title ?? c.posts.last.text);
    log('post.delete', {'channelId': c.id, 'postId': p.id});
    notifyListeners();
  }

  void toggleFavorite(Post p) {
    favorites.contains(p.id) ? favorites.remove(p.id) : favorites.add(p.id);
    log('favorite.set', {'postId': p.id, 'value': favorites.contains(p.id)});
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
    log('post.react', {'channelId': channelOf(p)?.id, 'postId': p.id, 'emoji': p.myReaction});
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
      log('address.save', {'entity': existing.toJson()});
      notifyListeners();
      return existing;
    }
    final a = Address('a${DateTime.now().microsecondsSinceEpoch}', label, text);
    addresses.add(a);
    log('address.save', {'entity': a.toJson()});
    notifyListeners();
    return a;
  }

  void deleteAddress(Address a) {
    addresses.remove(a);
    log('address.delete', {'id': a.id});
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
        _mirrorPostToItem(p, -l.qty, 'vente_en_ligne');
      }
    }
    orders.insert(0, o);
    cart.clear();
    _notice('Commande ${o.ref} payée', '${fmtInt(o.total)} FCFA via $provider');
    for (final c in o.channels) {
      if (c.mine) _notice('Nouvelle commande ${o.ref}', '${o.buyerName} · ${fmtInt(o.totalFor(c))} FCFA');
    }
    log('order.create', {'entity': o.toJson()});
    notifyListeners();
    return o;
  }

  void setStatus(Order o, OrderStatus s) {
    o.status = s;
    _notice('Commande ${o.ref}', 'Statut : ${s.label}');
    log('order.status', {'ref': o.ref, 'status': s.index, 'refunded': o.refunded});
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
        _mirrorPostToItem(p, l.qty, 'retour');
      }
    }
    _notice('Commande ${o.ref} annulée', 'Remboursement en cours');
    notifyListeners();
    final r = await paymentService.refund(PaymentRequest(o.provider, o.phone, o.total, o.ref));
    o.refunded = r.ok;
    _notice(r.ok ? 'Remboursement effectué' : 'Remboursement en attente', 'Commande ${o.ref} · ${fmtInt(o.total)} FCFA');
    log('order.status', {'ref': o.ref, 'status': o.status.index, 'refunded': o.refunded});
    notifyListeners();
  }

  List<Order> sellerOrders(Channel c) => orders.where((o) => o.lines.any((l) => l.channel == c)).toList();

  // ------------------------------------------------------------ avis
  bool canReview(Order o, CartLine l) => o.status == OrderStatus.delivered && !o.reviewed.contains(l.post.id);

  void addReview(Order o, CartLine l, int rating, String text) {
    final r = Review('r${DateTime.now().microsecondsSinceEpoch}', l.channel.id, l.post.id, user?.name ?? '', rating, text.trim());
    reviews.insert(0, r);
    o.reviewed.add(l.post.id);
    log('review.create', {'entity': r.toJson()});
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
    log('payout.request', {'entity': p.toJson()});
    notifyListeners();
    return null;
  }
  // ------------------------------------------------------------ catalogue physique & stock
  void changed() => notifyListeners();

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O/1/I

  /// Code court unique dans la boutique, généré sans connexion.
  String newCode(String channelId) {
    final r = Random.secure();
    while (true) {
      final c = String.fromCharCodes([for (var i = 0; i < 6; i++) _codeAlphabet.codeUnitAt(r.nextInt(_codeAlphabet.length))]);
      final used = items.any((i) => i.channelId == channelId && i.code == c) || blankCodes.any((b) => b.channelId == channelId && b.code == c);
      if (!used) return c;
    }
  }

  String labelUrl(Channel c, String code) => '${Brand.baseUrl}/q/${c.id}/$code';

  CatalogItem? itemById(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  CatalogItem? itemByPost(String postId) {
    for (final i in items) {
      if (i.postId == postId && i.active) return i;
    }
    return null;
  }

  List<CatalogGroup> groupsOf(Channel c, String? parentId) =>
      (groups.where((g) => g.channelId == c.id && g.parentId == parentId).toList())..sort((a, b) => normalizeText(a.name).compareTo(normalizeText(b.name)));

  List<CatalogItem> itemsOf(Channel c, {String? groupId, bool all = false}) =>
      (items.where((i) => i.channelId == c.id && i.active && (all || i.groupId == groupId)).toList())..sort((a, b) => normalizeText(a.title).compareTo(normalizeText(b.title)));

  /// Nombre de produits dans un sous-catalogue, sous-dossiers compris.
  int countIn(Channel c, String groupId) {
    var n = items.where((i) => i.channelId == c.id && i.active && i.groupId == groupId).length;
    for (final g in groupsOf(c, groupId)) {
      n += countIn(c, g.id);
    }
    return n;
  }

  /// Arbre aplati (avec profondeur) pour les listes déroulantes.
  List<MapEntry<CatalogGroup, int>> groupTree(Channel c, [String? parent, int depth = 0]) => [
        for (final g in groupsOf(c, parent)) ...[MapEntry(g, depth), ...groupTree(c, g.id, depth + 1)],
      ];

  String groupPath(CatalogGroup? g) {
    if (g == null) return 'Racine';
    final names = <String>[g.name];
    var p = g.parentId;
    while (p != null) {
      final x = groups.where((e) => e.id == p).firstOrNull;
      if (x == null) break;
      names.insert(0, x.name);
      p = x.parentId;
    }
    return names.join(' › ');
  }

  CatalogGroup saveGroup(Channel c, String name, {CatalogGroup? existing, String? parentId}) {
    final g = existing ?? CatalogGroup('g${DateTime.now().microsecondsSinceEpoch}', c.id, name.trim(), parentId);
    g.name = name.trim();
    if (existing == null) groups.add(g);
    log('catalog.group.save', {'entity': g.toJson()});
    notifyListeners();
    return g;
  }

  /// Supprime un sous-catalogue : ses produits et sous-dossiers remontent d'un niveau.
  void deleteGroup(CatalogGroup g) {
    for (final x in groups.where((e) => e.parentId == g.id)) {
      x.parentId = g.parentId;
      log('catalog.group.save', {'entity': x.toJson()});
    }
    for (final i in items.where((e) => e.groupId == g.id)) {
      i.groupId = g.parentId;
      log('catalog.item.save', {'entity': i.toJson(NoMediaIO())});
    }
    groups.remove(g);
    log('catalog.group.delete', {'id': g.id, 'channelId': g.channelId});
    notifyListeners();
  }

  List<String> createBlankCodes(Channel c, int n) {
    final out = <String>[];
    for (var i = 0; i < n; i++) {
      final code = newCode(c.id);
      blankCodes.add(CatalogCode(c.id, code));
      out.add(code);
    }
    log('catalog.codes.create', {'channelId': c.id, 'codes': out});
    notifyListeners();
    return out;
  }

  /// Crée ou met à jour un produit du catalogue. initialStock : stock de départ (création seulement).
  void saveItem(CatalogItem item, {int initialStock = 0}) {
    final isNew = !items.contains(item);
    if (isNew) items.add(item);
    blankCodes.removeWhere((b) => b.channelId == item.channelId && b.code == item.code);
    log('catalog.item.save', {'entity': item.toJson(NoMediaIO())});
    if (isNew && initialStock > 0) {
      moveStock(item, initialStock, 'initial', mirrorPost: false);
    }
    if (item.postId != null) _mirrorItemToPost(item, full: true);
    notifyListeners();
  }

  /// Archive le produit (il disparaît du catalogue ; son code n'est plus utilisé).
  void deleteItem(CatalogItem item) {
    final c = channelById(item.channelId);
    if (item.postId != null && c != null) unpublishItem(item, c);
    item.active = false;
    log('catalog.item.delete', {'id': item.id, 'channelId': item.channelId});
    notifyListeners();
  }

  /// Rattache une étiquette déjà imprimée à un produit existant.
  void reassignCode(CatalogItem item, String code) {
    item.code = code;
    blankCodes.removeWhere((b) => b.channelId == item.channelId && b.code == code);
    log('catalog.item.save', {'entity': item.toJson(NoMediaIO())});
    notifyListeners();
  }

  /// Mouvement de stock (delta > 0 entrée, < 0 sortie). Le stock ne descend jamais sous 0.
  StockMovement moveStock(CatalogItem it, int delta, String kind, {String note = '', bool mirrorPost = true, bool sync = true}) {
    final before = it.stock;
    it.stock = max(0, before + delta);
    final m = StockMovement('m${DateTime.now().microsecondsSinceEpoch}', it.id, it.channelId, it.stock - before, kind, note, user?.name ?? '', it.stock);
    movements.insert(0, m);
    if (movements.length > 2000) movements.removeLast();
    if (mirrorPost && it.postId != null) _mirrorItemToPost(it);
    if (before <= 0 && it.stock > 0 && alertItems.remove(it.id)) _notice('De retour : ${it.title}', 'Ce produit est de nouveau disponible.');
    if (it.out && before > 0) {
      _notice('Rupture : ${it.title}', 'Le stock est épuisé.');
    } else if (it.low && before > it.lowStock) {
      _notice('Stock faible : ${it.title}', 'Il en reste ${it.stock}.');
    }
    if (sync) log('stock.move', {'id': m.id, 'channelId': it.channelId, 'itemId': it.id, 'delta': delta, 'kind': kind, 'note': note});
    notifyListeners();
    return m;
  }

  /// Fixe le stock à une valeur comptée (inventaire / correction).
  void setStockTo(CatalogItem it, int target, {String note = ''}) {
    final d = target - it.stock;
    if (d != 0) moveStock(it, d, 'inventaire', note: note);
  }

  /// Stock catalogue -> publication en ligne liée.
  void _mirrorItemToPost(CatalogItem it, {bool full = false}) {
    final p = _postById(it.postId!);
    if (p == null) return;
    p.stock = it.stock;
    p.sold = it.stock <= 0;
    if (full) {
      p.title = it.title;
      p.price = it.price;
      p.category = it.category ?? p.category;
      p.text = _postText(it);
      if (it.images.isNotEmpty) {
        p.bytes = it.images.first;
        p.extra = it.images.skip(1).toList();
      }
      if (it.imageUrls.isNotEmpty) {
        p.imageUrl = it.imageUrls.first;
        p.extraUrls = it.imageUrls.skip(1).toList();
      }
      final c = channelOf(p);
      log('post.update', {'channelId': c?.id, 'postId': p.id, 'entity': p.toJson(NoMediaIO())});
    }
  }

  /// Vente / retour en ligne -> catalogue (la publication est déjà à jour).
  void _mirrorPostToItem(Post p, int delta, String kind) {
    final it = itemByPost(p.id);
    if (it != null) moveStock(it, delta, kind, mirrorPost: false);
  }

  String _postText(CatalogItem it) => [it.description, if (it.usage.isNotEmpty) 'Utilisation : ${it.usage}'].where((s) => s.trim().isNotEmpty).join('\n\n');

  /// Publie le produit dans la boutique en ligne (même stock).
  Post publishItem(CatalogItem it, Channel c, String category) {
    it.category = category;
    final p = Post(
      id: 'u${DateTime.now().microsecondsSinceEpoch}', type: PostType.image, time: nowHm(), title: it.title, price: it.price,
      category: category, stock: it.stock, sold: it.stock <= 0, text: _postText(it).isEmpty ? it.title : _postText(it),
      bytes: it.images.isEmpty ? null : it.images.first, extra: it.images.length > 1 ? it.images.skip(1).toList() : null,
      imageUrl: it.imageUrls.isEmpty ? null : it.imageUrls.first, extraUrls: it.imageUrls.length > 1 ? it.imageUrls.skip(1).toList() : null,
    );
    publish(c, p);
    it.postId = p.id;
    log('catalog.item.save', {'entity': it.toJson(NoMediaIO())});
    notifyListeners();
    return p;
  }

  void unpublishItem(CatalogItem it, Channel c) {
    final p = it.postId == null ? null : _postById(it.postId!);
    it.postId = null;
    if (p != null) deletePost(c, p);
    log('catalog.item.save', {'entity': it.toJson(NoMediaIO())});
    notifyListeners();
  }

  List<CatalogItem> lowStockOf(Channel c) => itemsOf(c, all: true).where((i) => i.low || i.out).toList();

  /// Interprète un scan : lien d'étiquette (/q/<boutique>/<code>), code court ou code-barres existant.
  ScanResult resolveScan(String raw) {
    final r = raw.trim();
    String? chId;
    var code = r;
    final u = Uri.tryParse(r);
    if (u != null && u.pathSegments.length >= 3 && u.pathSegments[0] == 'q') {
      chId = u.pathSegments[1];
      code = u.pathSegments[2];
    }
    final up = code.toUpperCase();
    for (final i in items) {
      if (!i.active || (chId != null && i.channelId != chId)) continue;
      if (i.code == up || i.barcodes.contains(code) || i.barcodes.contains(r)) {
        return ScanResult(ScanKind.item, channel: channelById(i.channelId), item: i, code: i.code);
      }
    }
    for (final b in blankCodes) {
      if ((chId == null || b.channelId == chId) && b.code == up) {
        return ScanResult(ScanKind.blank, channel: channelById(b.channelId), code: up);
      }
    }
    return ScanResult(ScanKind.unknown, code: code);
  }

  /// Comme resolveScan, avec consultation du serveur pour une étiquette d'une boutique inconnue.
  Future<ScanResult> resolveScanRemote(String raw) async {
    final u = Uri.tryParse(raw.trim());
    if (u == null || u.pathSegments.length < 3 || u.pathSegments[0] != 'q') return ScanResult(ScanKind.unknown, code: raw);
    final chId = u.pathSegments[1], code = u.pathSegments[2].toUpperCase();
    final data = await Services.catalog.lookup(chId, code);
    if (data == null) return ScanResult(ScanKind.unknown, code: code);
    if (data['blank'] == true) return ScanResult(ScanKind.blank, channel: channelById(chId), code: code);
    final it = CatalogItem.fromJson(Map<String, dynamic>.from(data['item']), NoMediaIO());
    var ch = channelById(chId);
    if (ch == null) {
      final cj = await Services.catalog.channel(chId);
      if (cj != null) {
        ch = Channel.fromJson(cj, NoMediaIO());
        ch.followed = false;
        channels.add(ch);
      }
    }
    if (ch == null) return ScanResult(ScanKind.unknown, code: code);
    items.removeWhere((x) => x.id == it.id);
    items.add(it);
    notifyListeners();
    return ScanResult(ScanKind.item, channel: ch, item: it, code: code);
  }

  // ------------------------------------------------------------ caisse, achats, équipe, réservations
  List<Channel> get worksAt => channels.where((c) => !c.mine && c.role != null).toList();

  /// Vente en magasin : retire le stock et enregistre la vente (une seule opération de synchro).
  Sale createSale(Channel c, List<SaleLine> lines, {String method = 'Espèces', String note = '', String customerPhone = ''}) {
    final s = Sale('s${DateTime.now().microsecondsSinceEpoch}', c.id, user?.name ?? '', method, note, customerPhone, lines,
        lines.fold(0, (a, l) => a + l.total), lines.fold(0, (a, l) => a + l.unitCost * l.qty));
    for (final l in lines) {
      final it = itemById(l.itemId);
      if (it != null) moveStock(it, -l.qty, 'vente', note: 'Caisse ${s.id}', sync: false);
    }
    sales.insert(0, s);
    log('sale.create', {'entity': s.toJson()});
    notifyListeners();
    return s;
  }

  void voidSale(Sale s) {
    if (s.voided) return;
    for (final l in s.lines) {
      final it = itemById(l.itemId);
      if (it != null) moveStock(it, l.qty, 'retour', note: 'Annulation vente ${s.id}', sync: false);
    }
    s.voided = true;
    log('sale.void', {'id': s.id, 'channelId': s.channelId});
    notifyListeners();
  }

  List<Sale> salesOf(Channel c, {DateTime? since}) =>
      sales.where((s) => s.channelId == c.id && (since == null || !s.date.isBefore(since))).toList()..sort((a, b) => b.date.compareTo(a.date));

  /// Frais répartis au prorata de la valeur de chaque ligne ; coût du produit = moyenne pondérée avec l'ancien stock.
  List<PurchaseLine> landedLines(List<PurchaseLine> input, int extra) {
    final totalValue = input.fold(0, (a, l) => a + l.qty * l.unitCost);
    final totalQty = input.fold(0, (a, l) => a + l.qty);
    return [
      for (final l in input)
        PurchaseLine(l.itemId, l.qty, l.unitCost,
            (l.unitCost + (totalValue > 0 ? extra * (l.qty * l.unitCost) / totalValue : extra * l.qty / totalQty) / l.qty).round()),
    ];
  }

  Purchase savePurchase(Channel c, String supplier, int extra, String note, List<PurchaseLine> input) {
    final lines = landedLines(input, extra);
    for (final l in lines) {
      final it = itemById(l.itemId);
      if (it == null) continue;
      it.cost = it.cost > 0 && it.stock + l.qty > 0 ? ((it.stock * it.cost + l.qty * l.landed) / (it.stock + l.qty)).round() : l.landed;
      moveStock(it, l.qty, 'entree', note: 'Achat $supplier'.trim(), sync: false);
    }
    final p = Purchase('pu${DateTime.now().microsecondsSinceEpoch}', c.id, supplier, note, extra, lines);
    purchases.insert(0, p);
    log('purchase.create', {'entity': p.toJson()});
    notifyListeners();
    return p;
  }

  List<Member> membersOf(Channel c) => members.where((m) => m.channelId == c.id).toList();

  void inviteMember(Channel c, String phone, String name, String role) {
    final p = normalizePhone(phone);
    members.removeWhere((m) => m.channelId == c.id && m.phone == p);
    members.add(Member(c.id, p, name.trim(), role));
    log('team.invite', {'channelId': c.id, 'phone': phone, 'name': name.trim(), 'role': role});
    notifyListeners();
  }

  void removeMember(Channel c, Member m) {
    members.remove(m);
    log('team.remove', {'channelId': c.id, 'phone': m.phone});
    notifyListeners();
  }

  Reservation reserve(CatalogItem it, Channel c, int qty, String name, String phone) {
    final now = DateTime.now();
    final r = Reservation('r${now.microsecondsSinceEpoch}', c.id, it.id, it.title, qty, name, phone, 'pending', now, now.add(Duration(hours: Brand.reservationHours)), mine: true);
    reservations.insert(0, r);
    if (c.staff) moveStock(it, -qty, 'reservation', note: 'Réservation ${r.id}', sync: false);
    log('reservation.create', {'id': r.id, 'itemId': it.id, 'qty': qty, 'name': name, 'phone': phone});
    notifyListeners();
    return r;
  }

  void setReservation(Reservation r, String status) {
    if (r.status == status || !r.active) return;
    final c = channelById(r.channelId);
    final it = itemById(r.itemId);
    final staff = c?.staff == true && it != null;
    if (status == 'cancelled' && staff) moveStock(it, r.qty, 'retour', note: 'Annulation réservation', sync: false);
    if (status == 'collected' && staff) {
      sales.insert(0, Sale('s_${r.id}', r.channelId, user?.name ?? '', 'Espèces', 'Réservation ${r.id}', r.phone, [SaleLine(it.id, it.title, r.qty, it.price, it.cost)], it.price * r.qty, it.cost * r.qty));
    }
    r.status = status;
    log('reservation.status', {'id': r.id, 'status': status});
    notifyListeners();
  }

  /// Réservations échues : le stock réservé est restitué (le serveur fait de même de son côté).
  void expireReservations() {
    final now = DateTime.now();
    var changed = false;
    for (final r in reservations.where((r) => r.active && r.expires.isBefore(now)).toList()) {
      final it = itemById(r.itemId);
      if (channelById(r.channelId)?.staff == true && it != null) moveStock(it, r.qty, 'retour', note: 'Réservation expirée', sync: false);
      r.status = 'expired';
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void toggleAlert(CatalogItem it) {
    alertItems.contains(it.id) ? alertItems.remove(it.id) : alertItems.add(it.id);
    log('alert.subscribe', {'itemId': it.id, 'value': alertItems.contains(it.id)});
    notifyListeners();
  }

  /// Recherche d'un client qui n'a rien donné dans une boutique : signal de demande pour le vendeur.
  void logDemand(Channel c, String term) {
    final t = normalizeText(term).trim();
    if (t.length < 3) return;
    final ex = demand.where((d) => d.channelId == c.id && d.term == t).firstOrNull;
    if (ex != null) {
      ex.count++;
      ex.last = DateTime.now();
    } else {
      demand.add(DemandTerm(c.id, t, 1, DateTime.now()));
    }
    log('demand.log', {'channelId': c.id, 'term': t});
    notifyListeners();
  }

  // ------------------------------------------------------------ recherche par photo
  Future<void> ensureSigs(CatalogItem it) async {
    if (it.sigs.length == it.images.length) return;
    it.sigs = [for (final b in it.images) await imageEmbedder.embed(b)];
  }

  List<MapEntry<CatalogItem, double>> searchByPhoto(List<double> sig, {Channel? channel, int limit = 5}) {
    final out = <MapEntry<CatalogItem, double>>[];
    for (final i in items) {
      if (!i.active || (channel != null && i.channelId != channel.id)) continue;
      var best = 0.0;
      for (final s in i.sigs) {
        final v = imageEmbedder.similarity(sig, s);
        if (v > best) best = v;
      }
      if (best > 0) out.add(MapEntry(i, best));
    }
    out.sort((a, b) => b.value.compareTo(a.value));
    return out.take(limit).toList();
  }

}

final app = AppState();
