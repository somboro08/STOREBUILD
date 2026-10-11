import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/contact_buttons.dart';
import '../widgets/helpers.dart';
import '../widgets/verified_badge.dart';
import 'media_gallery_screen.dart';
import 'reviews_screen.dart';
import 'search_screen.dart';
import 'store_dashboard_screen.dart';

/// Infos de la boutique.
class ChannelInfoScreen extends StatelessWidget {
  final Channel channel;
  const ChannelInfoScreen({super.key, required this.channel});

  Widget _action(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(children: [
          Container(width: 78, height: 46, decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(24)), child: Icon(icon, size: 22)),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12.5)),
        ]),
      );

  Widget _row(IconData icon, String title, {String? sub, Widget? trailing, VoidCallback? onTap, Color? color}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color ?? C.sub, size: 24),
            SizedBox(width: 24),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 16.5, color: color)),
                if (sub != null) ...[SizedBox(height: 3), Text(sub, style: TextStyle(color: C.sub, fontSize: 14, height: 1.3))],
              ]),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ch = channel;
    return Scaffold(
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final media = ch.posts.where((p) => p.type != PostType.text).toList();
          return ListView(children: [
            Center(child: ChannelAvatar(color: ch.color, name: ch.name, bytes: ch.logo, url: ch.logoUrl, size: 120)),
            SizedBox(height: 16),
            Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: ChannelTitle(ch, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)))),
            SizedBox(height: 4),
            Center(child: Text('Boutique • ${fmtInt(ch.followers)} abonnés', style: TextStyle(color: C.sub, fontSize: 15))),
            SizedBox(height: 4),
            Center(child: RatingLine(ch)),
            SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _action(ch.followed ? Icons.check : Icons.add, ch.followed ? 'Suivie' : 'Suivre', () => app.toggleFollow(ch)),
              _action(Icons.shortcut, 'Transférer', () => shareLink(context, 's/${ch.id}', message: ch.name)),
              _action(Icons.share_outlined, 'Partager', () => shareLink(context, 's/${ch.id}', message: ch.name)),
              _action(Icons.search, 'Rechercher', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(channel: ch)))),
            ]),
            if (!ch.mine && ch.phone.isNotEmpty) Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: ContactButtons(phone: ch.phone, message: 'Bonjour, je vous contacte depuis Whatstore.')),
            SizedBox(height: 14),
            Divider(color: C.divider, thickness: 8, height: 8),
            if (ch.created.isNotEmpty) Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text('Créée le ${ch.created}', style: TextStyle(color: C.sub, fontSize: 14))),
            if (ch.description.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ch.description, style: TextStyle(fontSize: 15.5, height: 1.35)),
                  if (ch.zone.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Row(children: [Icon(Icons.place_outlined, size: 17, color: C.sub), SizedBox(width: 6), Expanded(child: Text(ch.zone, style: TextStyle(color: C.sub, fontSize: 14)))]),
                  ],
                  SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.local_shipping_outlined, size: 17, color: C.sub),
                    SizedBox(width: 6),
                    Text(ch.delivers ? 'Livraison : ${ch.deliveryFee == 0 ? 'gratuite' : '${fmtInt(ch.deliveryFee)} FCFA'}' : 'Retrait en boutique uniquement', style: TextStyle(color: C.sub, fontSize: 14)),
                  ]),
                ]),
              ),
            Divider(color: C.divider, thickness: 8, height: 22),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaGalleryScreen(channel: ch))),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Médias et liens', style: TextStyle(color: C.sub, fontSize: 15)),
                  Text('${ch.id == 'martistore' ? 329 : media.length}  ›', style: TextStyle(color: C.sub, fontSize: 15)),
                ]),
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.only(left: 16), children: [
                for (final p in media)
                  Container(
                    width: 92, margin: EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(8)),
                    clipBehavior: Clip.antiAlias,
                    child: p.bytes != null ? Image.memory(p.bytes!, fit: BoxFit.cover) : (p.imageUrl != null ? Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: Colors.white38)) : Icon(Icons.image_outlined, color: Colors.white38)),
                  ),
              ]),
            ),
            Divider(color: C.divider, thickness: 8, height: 26),
            _row(Icons.star_outline, 'Avis', sub: '${app.reviewsOf(ch).length} avis', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsScreen(channel: ch)))),
            _row(Icons.perm_media_outlined, 'Gérer le stockage', sub: '${ch.storageMo.toStringAsFixed(1).replaceAll('.', ',')} Mo', onTap: () async {
              if (ch.storageMo > 0 && await confirmDialog(context, 'Libérer l\'espace ?', 'Supprimer les médias téléchargés de cette boutique.', ok: 'Effacer', danger: true)) app.clearStorage(ch);
            }),
            _row(
              Icons.notifications_none, 'Mode silencieux',
              trailing: Switch(
                value: ch.muted,
                onChanged: (_) => app.toggleMute(ch),
                thumbColor: WidgetStatePropertyAll(Color(0xFF0B141A)),
                thumbIcon: WidgetStatePropertyAll(Icon(Icons.check, color: ch.muted ? C.green : Colors.transparent)),
                trackColor: WidgetStatePropertyAll(ch.muted ? C.green : C.chip),
                trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
            Divider(color: C.divider, thickness: 8, height: 8),
            _row(Icons.public, 'Boutique publique', sub: 'N\'importe qui peut trouver cette boutique et voir tout ce qui y est partagé.',
                onTap: () => infoDialog(context, 'Boutique publique', 'Les boutiques sont publiques : tout le monde peut les trouver dans Explorer et voir leurs produits.')),
            _row(Icons.dialpad, 'Confidentialité du profil',
                sub: 'Pour cette boutique, la confidentialité de votre profil et de votre numéro de téléphone est renforcée. Appuyez pour en savoir plus.',
                onTap: () => infoDialog(context, 'Confidentialité', 'Le vendeur ne voit pas ton numéro tant que tu ne passes pas commande.')),
            if (ch.mine)
              _row(Icons.dashboard_customize_outlined, 'Gérer ma boutique', sub: 'Produits, commandes, revenus', color: C.green,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDashboardScreen(channel: ch))))
            else
              _row(Icons.flag_outlined, 'Signaler la boutique', color: Colors.redAccent, onTap: () => showReportSheet(context, ch)),
            SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}
