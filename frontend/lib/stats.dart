import 'catalog_models.dart';
import 'data.dart';
import 'state.dart';

class ItemStat {
  final CatalogItem item;
  int qty = 0, revenue = 0, profit = 0;
  ItemStat(this.item);
}

/// Chiffres d'une boutique sur une période : ventes en magasin + commandes en ligne livrées.
class StoreStats {
  int total = 0, count = 0, profit = 0, inStore = 0, online = 0, stockValue = 0;
  final Map<DateTime, int> byDay = {};
  List<ItemStat> top = [];
  List<CatalogItem> slow = [], out = [];
}

StoreStats computeStats(AppState a, Channel c, int days) {
  final now = DateTime.now();
  final since = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
  final st = StoreStats();
  final per = <String, ItemStat>{};
  ItemStat statOf(CatalogItem it) => per.putIfAbsent(it.id, () => ItemStat(it));
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  for (final s in a.sales.where((s) => s.channelId == c.id && !s.voided && !s.date.isBefore(since))) {
    st.total += s.total;
    st.inStore += s.total;
    st.count++;
    st.profit += s.profit;
    st.byDay[day(s.date)] = (st.byDay[day(s.date)] ?? 0) + s.total;
    for (final l in s.lines) {
      final it = a.itemById(l.itemId);
      if (it == null) continue;
      final x = statOf(it);
      x.qty += l.qty;
      x.revenue += l.total;
      x.profit += l.total - l.unitCost * l.qty;
    }
  }
  for (final o in a.orders.where((o) => o.status == OrderStatus.delivered && !o.date.isBefore(since) && o.channels.contains(c))) {
    final v = o.itemsFor(c);
    st.total += v;
    st.online += v;
    st.count++;
    st.byDay[day(o.date)] = (st.byDay[day(o.date)] ?? 0) + v;
    for (final l in o.lines.where((l) => l.channel == c)) {
      final it = a.itemByPost(l.post.id);
      if (it == null) continue;
      final x = statOf(it);
      x.qty += l.qty;
      x.revenue += l.total;
      x.profit += l.total - it.cost * l.qty;
      st.profit += l.total - it.cost * l.qty;
    }
  }
  final all = a.itemsOf(c, all: true);
  st.top = (per.values.toList()..sort((x, y) => y.revenue.compareTo(x.revenue))).take(5).toList();
  st.slow = (all.where((i) => i.stock > 0 && !per.containsKey(i.id)).toList()..sort((x, y) => (y.stock * y.cost).compareTo(x.stock * x.cost))).take(8).toList();
  st.out = all.where((i) => i.out).toList();
  st.stockValue = all.fold(0, (s, i) => s + i.stock * i.cost);
  return st;
}
