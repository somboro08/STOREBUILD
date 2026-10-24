import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/catalog_nav.dart';
import '../screens/channel_feed_screen.dart';
import '../screens/product_detail_screen.dart';
import '../state.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Ouvre un lien whatstore.store/s/<boutique> ou /p/<produit>. Retourne false si introuvable.
bool openLink(String raw) {
  final u = Uri.tryParse(raw.trim());
  final nav = navigatorKey.currentState;
  if (u == null || nav == null) return false;
  final seg = u.pathSegments;
  if (seg.length < 2) return false;
  if (app.user == null) {
    app.pendingLink = raw;
    return true;
  }
  if (seg[0] == 'q' && seg.length >= 3) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return false;
    openScanned(ctx, raw);
    return true;
  }
  if (seg[0] == 's') {
    final c = app.channelById(seg[1]);
    if (c == null) return false;
    nav.push(MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: c)));
    return true;
  }
  if (seg[0] == 'p') {
    final r = app.productById(seg[1]);
    if (r == null) return false;
    nav.push(MaterialPageRoute(builder: (_) => ProductDetailScreen(channel: r.channel, post: r.post)));
    return true;
  }
  return false;
}

/// Écoute les liens entrants (nécessite la configuration Android/iOS : voir docs/PLATFORM_SETUP.md).
Future<void> initDeepLinks() async {
  try {
    final links = AppLinks();
    final initial = await links.getInitialLink();
    if (initial != null) WidgetsBinding.instance.addPostFrameCallback((_) => openLink(initial.toString()));
    links.uriLinkStream.listen((u) => openLink(u.toString()));
  } catch (_) {}
}
