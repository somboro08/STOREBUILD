import 'dart:typed_data';
import 'data.dart';

/// Motifs de mouvement de stock.
const stockKinds = {
  'entree': 'Entrée',
  'vente': 'Vente en magasin',
  'perte': 'Perte / casse',
  'retour': 'Retour',
  'inventaire': 'Correction / inventaire',
  'vente_en_ligne': 'Vente en ligne',
  'initial': 'Stock initial',
  'reservation': 'Réservation',
};

const memberRoles = {'manager': 'Gérant', 'cashier': 'Vendeur / caissier', 'stock': 'Magasinier'};
const payMethods = ['Espèces', 'Mobile money', 'Autre'];

const itemUnits = ['pièce', 'paquet', 'carton', 'douzaine', 'kg', 'litre', 'mètre', 'paire'];

/// Sous-catalogue (dossier) d'une boutique. parentId null = racine.
class CatalogGroup {
  final String id, channelId;
  String? parentId;
  String name;
  CatalogGroup(this.id, this.channelId, this.name, [this.parentId]);
  Map<String, dynamic> toJson() => {'id': id, 'channelId': channelId, 'parentId': parentId, 'name': name};
  factory CatalogGroup.fromJson(Map<String, dynamic> j) => CatalogGroup(j['id'], j['channelId'], j['name'] ?? '', j['parentId']);
}

/// Produit du catalogue physique : identifié par un code QR court (code) et/ou des codes-barres existants.
class CatalogItem {
  final String id, channelId;
  String code, name, description, usage, location, unit, variant;
  String? groupId, postId, category;
  List<String> barcodes, imageUrls;
  List<Uint8List> images;
  List<List<String>> details; // [[nom, valeur], ...]
  List<List<double>> sigs; // empreintes visuelles des photos (recherche par photo)
  int price, cost, stock, lowStock;
  bool active;

  CatalogItem({
    required this.id,
    required this.channelId,
    required this.code,
    required this.name,
    this.description = '',
    this.usage = '',
    this.location = '',
    this.unit = 'pièce',
    this.variant = '',
    this.groupId,
    this.postId,
    this.category,
    List<String>? barcodes,
    List<String>? imageUrls,
    List<Uint8List>? images,
    List<List<String>>? details,
    List<List<double>>? sigs,
    this.price = 0,
    this.cost = 0,
    this.stock = 0,
    this.lowStock = 3,
    this.active = true,
  })  : barcodes = barcodes ?? [],
        imageUrls = imageUrls ?? [],
        images = images ?? [],
        details = details ?? [],
        sigs = sigs ?? [];

  String get title => variant.isEmpty ? name : '$name · $variant';
  bool get out => stock <= 0;
  bool get low => stock > 0 && lowStock > 0 && stock <= lowStock;
  String get availability => out ? 'Rupture' : (low ? 'Stock limité' : 'Disponible');
  int get margin => price - cost;

  /// includeStock = false pour les envois à l'API : le stock ne change que par mouvements.
  Map<String, dynamic> toJson(MediaIO io) => {
        'id': id, 'channelId': channelId, 'code': code, 'name': name, 'description': description, 'usage': usage,
        'location': location, 'unit': unit, 'variant': variant, 'groupId': groupId, 'postId': postId, 'category': category,
        'barcodes': barcodes, 'imageUrls': imageUrls, 'details': details, 'price': price, 'cost': cost, 'stock': stock,
        'lowStock': lowStock, 'active': active,
        'imgs': [for (var i = 0; i < images.length; i++) io.saveImage('${id}_c$i', images[i])],
        if (io is! NoMediaIO) 'sigs': sigs,
      };

  factory CatalogItem.fromJson(Map<String, dynamic> j, MediaIO io) {
    final imgs = <Uint8List>[];
    for (final n in (j['imgs'] as List? ?? [])) {
      final b = io.loadImage(n as String?);
      if (b != null) imgs.add(b);
    }
    return CatalogItem(
      id: j['id'], channelId: j['channelId'], code: j['code'] ?? '', name: j['name'] ?? '',
      description: j['description'] ?? '', usage: j['usage'] ?? '', location: j['location'] ?? '',
      unit: j['unit'] ?? 'pièce', variant: j['variant'] ?? '', groupId: j['groupId'], postId: j['postId'],
      category: j['category'], barcodes: List<String>.from(j['barcodes'] ?? []), imageUrls: List<String>.from(j['imageUrls'] ?? []),
      images: imgs, details: [for (final e in (j['details'] as List? ?? [])) List<String>.from(e as List)],
      sigs: [for (final x in (j['sigs'] as List? ?? [])) List<double>.from((x as List).map((e) => (e as num).toDouble()))],
      price: j['price'] ?? 0, cost: j['cost'] ?? 0, stock: j['stock'] ?? 0, lowStock: j['lowStock'] ?? 3, active: j['active'] ?? true,
    );
  }
}

class StockMovement {
  final String id, itemId, channelId, kind, note, by;
  final int delta, after;
  final DateTime date;
  StockMovement(this.id, this.itemId, this.channelId, this.delta, this.kind, this.note, this.by, this.after, [DateTime? d]) : date = d ?? DateTime.now();
  Map<String, dynamic> toJson() => {'id': id, 'itemId': itemId, 'channelId': channelId, 'delta': delta, 'kind': kind, 'note': note, 'by': by, 'after': after, 'date': date.toIso8601String()};
  factory StockMovement.fromJson(Map<String, dynamic> j) =>
      StockMovement(j['id'], j['itemId'], j['channelId'], j['delta'] ?? 0, j['kind'] ?? '', j['note'] ?? '', j['by'] ?? '', j['after'] ?? 0, DateTime.parse(j['date']));
}

/// Code d'étiquette généré mais pas encore associé à un produit.
class CatalogCode {
  final String channelId, code;
  CatalogCode(this.channelId, this.code);
  Map<String, dynamic> toJson() => {'channelId': channelId, 'code': code};
  factory CatalogCode.fromJson(Map<String, dynamic> j) => CatalogCode(j['channelId'], j['code']);
}

enum ScanKind { item, blank, unknown }

class ScanResult {
  final ScanKind kind;
  final Channel? channel;
  final CatalogItem? item;
  final String? code;
  ScanResult(this.kind, {this.channel, this.item, this.code});
}

class SaleLine {
  final String itemId, name;
  final int qty, unitPrice, unitCost;
  const SaleLine(this.itemId, this.name, this.qty, this.unitPrice, this.unitCost);
  int get total => qty * unitPrice;
  Map<String, dynamic> toJson() => {'itemId': itemId, 'name': name, 'qty': qty, 'unitPrice': unitPrice, 'unitCost': unitCost};
  factory SaleLine.fromJson(Map<String, dynamic> j) => SaleLine(j['itemId'], j['name'] ?? '', j['qty'] ?? 1, j['unitPrice'] ?? 0, j['unitCost'] ?? 0);
}

/// Vente enregistrée en caisse (magasin physique).
class Sale {
  final String id, channelId, cashier, method, note, customerPhone;
  final List<SaleLine> lines;
  final int total, costTotal;
  bool voided;
  final DateTime date;
  Sale(this.id, this.channelId, this.cashier, this.method, this.note, this.customerPhone, this.lines, this.total, this.costTotal, [DateTime? d, this.voided = false]) : date = d ?? DateTime.now();
  int get profit => total - costTotal;
  Map<String, dynamic> toJson() => {
        'id': id, 'channelId': channelId, 'cashier': cashier, 'method': method, 'note': note, 'customerPhone': customerPhone,
        'lines': [for (final l in lines) l.toJson()], 'total': total, 'costTotal': costTotal, 'voided': voided, 'date': date.toIso8601String(),
      };
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        j['id'], j['channelId'], j['cashier'] ?? '', j['method'] ?? 'Espèces', j['note'] ?? '', j['customerPhone'] ?? '',
        [for (final l in (j['lines'] as List? ?? [])) SaleLine.fromJson(Map<String, dynamic>.from(l))], j['total'] ?? 0, j['costTotal'] ?? 0,
        DateTime.parse(j['date']), j['voided'] ?? false,
      );
}

class PurchaseLine {
  final String itemId;
  final int qty, unitCost, landed; // landed = coût d'achat réel (frais répartis)
  const PurchaseLine(this.itemId, this.qty, this.unitCost, [this.landed = 0]);
  Map<String, dynamic> toJson() => {'itemId': itemId, 'qty': qty, 'unitCost': unitCost, 'landed': landed};
  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(j['itemId'], j['qty'] ?? 1, j['unitCost'] ?? 0, j['landed'] ?? 0);
}

/// Arrivage de marchandises : prix d'achat + frais (transport, douane) -> coût réel par produit.
class Purchase {
  final String id, channelId, supplier, note;
  final int extraCosts;
  final List<PurchaseLine> lines;
  final DateTime date;
  Purchase(this.id, this.channelId, this.supplier, this.note, this.extraCosts, this.lines, [DateTime? d]) : date = d ?? DateTime.now();
  Map<String, dynamic> toJson() => {
        'id': id, 'channelId': channelId, 'supplier': supplier, 'note': note, 'extraCosts': extraCosts,
        'lines': [for (final l in lines) l.toJson()], 'date': date.toIso8601String(),
      };
  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        j['id'], j['channelId'], j['supplier'] ?? '', j['note'] ?? '', j['extraCosts'] ?? 0,
        [for (final l in (j['lines'] as List? ?? [])) PurchaseLine.fromJson(Map<String, dynamic>.from(l))], DateTime.parse(j['date']),
      );
}

/// Réservation en magasin (click & collect) : le stock est retiré jusqu'au retrait ou à l'expiration.
class Reservation {
  final String id, channelId, itemId, itemName, name, phone;
  final int qty;
  String status; // pending | ready | collected | cancelled | expired
  final DateTime date, expires;
  final bool mine; // faite par l'utilisateur de cet appareil
  Reservation(this.id, this.channelId, this.itemId, this.itemName, this.qty, this.name, this.phone, this.status, this.date, this.expires, {this.mine = false});
  bool get active => status == 'pending' || status == 'ready';
  Map<String, dynamic> toJson() => {
        'id': id, 'channelId': channelId, 'itemId': itemId, 'itemName': itemName, 'qty': qty, 'name': name, 'phone': phone,
        'status': status, 'date': date.toIso8601String(), 'expires': expires.toIso8601String(), 'mine': mine,
      };
  factory Reservation.fromJson(Map<String, dynamic> j) => Reservation(
        j['id'], j['channelId'], j['itemId'], j['itemName'] ?? '', j['qty'] ?? 1, j['name'] ?? '', j['phone'] ?? '', j['status'] ?? 'pending',
        DateTime.parse(j['date']), DateTime.parse(j['expires']), mine: j['mine'] ?? false,
      );
}

class Member {
  final String channelId, phone;
  String name, role;
  Member(this.channelId, this.phone, this.name, this.role);
  Map<String, dynamic> toJson() => {'channelId': channelId, 'phone': phone, 'name': name, 'role': role};
  factory Member.fromJson(Map<String, dynamic> j) => Member(j['channelId'], j['phone'], j['name'] ?? '', j['role'] ?? 'cashier');
}

/// Recherche de clients qui n'a rien donné : ce que la boutique devrait peut-être stocker.
class DemandTerm {
  final String channelId, term;
  int count;
  DateTime last;
  DemandTerm(this.channelId, this.term, this.count, this.last);
  Map<String, dynamic> toJson() => {'channelId': channelId, 'term': term, 'count': count, 'last': last.toIso8601String()};
  factory DemandTerm.fromJson(Map<String, dynamic> j) => DemandTerm(j['channelId'], j['term'] ?? '', j['count'] ?? 1, DateTime.parse(j['last']));
}
