import 'brand.dart';
import 'data.dart';
import 'package:flutter/material.dart';

class AppUser {
  String name, phone;
  AppUser(this.name, this.phone);
}

/// Opération à synchroniser avec l'API (file d'attente hors-ligne).
class SyncOp {
  final String id, type;
  final Map<String, dynamic> payload;
  final DateTime date;
  SyncOp(this.id, this.type, this.payload, [DateTime? d]) : date = d ?? DateTime.now();
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'payload': payload, 'date': date.toIso8601String()};
  factory SyncOp.fromJson(Map<String, dynamic> j) =>
      SyncOp(j['id'], j['type'], Map<String, dynamic>.from(j['payload'] ?? {}), DateTime.parse(j['date']));
}

class Review {
  final String id, channelId, postId, author, text;
  final int rating;
  final DateTime date;
  Review(this.id, this.channelId, this.postId, this.author, this.rating, this.text, [DateTime? d]) : date = d ?? DateTime.now();
  Map<String, dynamic> toJson() => {'id': id, 'channelId': channelId, 'postId': postId, 'author': author, 'rating': rating, 'text': text, 'date': date.toIso8601String()};
  factory Review.fromJson(Map<String, dynamic> j) =>
      Review(j['id'], j['channelId'], j['postId'] ?? '', j['author'] ?? '', j['rating'] ?? 5, j['text'] ?? '', DateTime.parse(j['date']));
}

class Address {
  final String id;
  String label, text;
  Address(this.id, this.label, this.text);
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'text': text};
  factory Address.fromJson(Map<String, dynamic> j) => Address(j['id'], j['label'] ?? '', j['text'] ?? '');
}

class Payout {
  final String id, channelId, phone;
  final int amount;
  final DateTime date;
  String status;
  Payout(this.id, this.channelId, this.amount, this.phone, [DateTime? d, this.status = 'demandé']) : date = d ?? DateTime.now();
  Map<String, dynamic> toJson() => {'id': id, 'channelId': channelId, 'amount': amount, 'phone': phone, 'date': date.toIso8601String(), 'status': status};
  factory Payout.fromJson(Map<String, dynamic> j) => Payout(j['id'], j['channelId'], j['amount'] ?? 0, j['phone'] ?? '', DateTime.parse(j['date']), j['status'] ?? 'demandé');
}

class AppNotice {
  final String id, title, body;
  final DateTime date;
  bool read;
  AppNotice(this.id, this.title, this.body, [DateTime? d, this.read = false]) : date = d ?? DateTime.now();
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'date': date.toIso8601String(), 'read': read};
  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(j['id'], j['title'] ?? '', j['body'] ?? '', DateTime.parse(j['date']), j['read'] ?? false);
}

class Report {
  final String channelId, reason, by;
  final DateTime date;
  Report(this.channelId, this.reason, this.by, [DateTime? d]) : date = d ?? DateTime.now();
  Map<String, dynamic> toJson() => {'channelId': channelId, 'reason': reason, 'by': by, 'date': date.toIso8601String()};
  factory Report.fromJson(Map<String, dynamic> j) => Report(j['channelId'], j['reason'] ?? '', j['by'] ?? '', DateTime.parse(j['date']));
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

class CartLine {
  final Channel channel;
  final Post post;
  int qty;
  final String variant;
  CartLine(this.channel, this.post, this.qty, [this.variant = '']);
  int get total => (post.price ?? 0) * qty;
  String get key => '${post.id}|$variant';
  Map<String, dynamic> toJson() => {'c': channel.id, 'p': post.id, 'q': qty, 'v': variant, 't': post.title, 'pr': post.price};
  static CartLine? fromJson(Map<String, dynamic> j, Channel? Function(String) find) {
    final c = find(j['c']);
    if (c == null) return null;
    final p = c.posts.where((x) => x.id == j['p']).firstOrNull ??
        Post(id: j['p'], type: PostType.image, time: '', text: '', title: j['t'], price: j['pr']);
    return CartLine(c, p, j['q'] ?? 1, j['v'] ?? '');
  }
}

class ProductRef {
  final Channel channel;
  final Post post;
  ProductRef(this.channel, this.post);
}

class Order {
  final String ref, provider, phone, buyerName, address;
  final List<CartLine> lines;
  final int itemsTotal;
  final bool delivery;
  final Map<String, int> fees; // frais de livraison par boutique
  final DateTime date;
  OrderStatus status;
  bool refunded;
  final Set<String> reviewed; // ids des produits déjà notés

  Order({
    required this.ref,
    required this.lines,
    required this.provider,
    required this.phone,
    required this.buyerName,
    this.address = '',
    required this.delivery,
    Map<String, int>? fees,
    DateTime? date,
    this.status = OrderStatus.paid,
    this.refunded = false,
    Set<String>? reviewed,
  })  : fees = fees ?? {},
        date = date ?? DateTime.now(),
        reviewed = reviewed ?? {},
        itemsTotal = lines.fold(0, (a, l) => a + l.total);

  int get feeTotal => fees.values.fold(0, (a, b) => a + b);
  int get total => itemsTotal + feeTotal;
  int itemsFor(Channel c) => lines.where((l) => l.channel == c).fold(0, (a, l) => a + l.total);
  int feeFor(Channel c) => fees[c.id] ?? 0;
  int totalFor(Channel c) => itemsFor(c) + feeFor(c);
  int commissionFor(Channel c) => (itemsFor(c) * Brand.commissionRate).round();
  int netFor(Channel c) => totalFor(c) - commissionFor(c);
  bool get active => status != OrderStatus.delivered && status != OrderStatus.cancelled;
  Set<Channel> get channels => {for (final l in lines) l.channel};

  Map<String, dynamic> toJson() => {
        'ref': ref, 'provider': provider, 'phone': phone, 'buyer': buyerName, 'address': address,
        'lines': [for (final l in lines) l.toJson()], 'delivery': delivery, 'fees': fees,
        'date': date.toIso8601String(), 'status': status.index, 'refunded': refunded, 'reviewed': reviewed.toList(),
      };

  static Order fromJson(Map<String, dynamic> j, Channel? Function(String) find) => Order(
        ref: j['ref'], provider: j['provider'] ?? '', phone: j['phone'] ?? '', buyerName: j['buyer'] ?? '',
        address: j['address'] ?? '', delivery: j['delivery'] ?? false,
        lines: (j['lines'] as List? ?? []).map((x) => CartLine.fromJson(Map<String, dynamic>.from(x), find)).whereType<CartLine>().toList(),
        fees: Map<String, int>.from(j['fees'] ?? {}), date: DateTime.parse(j['date']),
        status: OrderStatus.values[j['status'] ?? 0], refunded: j['refunded'] ?? false,
        reviewed: Set<String>.from(j['reviewed'] ?? []),
      );
}
