import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../brand.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../screens/publish_product_screen.dart';

const reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m), duration: Duration(seconds: 2)));

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Future<bool> confirmDialog(BuildContext c, String title, String body, {String ok = 'Confirmer', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      backgroundColor: C.bubble,
      title: Text(title),
      content: Text(body, style: TextStyle(color: C.sub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: TextStyle(color: C.sub))),
        TextButton(onPressed: () => Navigator.pop(d, true), child: Text(ok, style: TextStyle(color: danger ? Colors.redAccent : C.green))),
      ],
    ),
  );
  return r == true;
}

Future<void> infoDialog(BuildContext c, String title, String body) => showDialog(
      context: c,
      builder: (d) => AlertDialog(
        backgroundColor: C.bubble,
        title: Text(title),
        content: Text(body, style: TextStyle(color: C.sub, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text('OK', style: TextStyle(color: C.green)))],
      ),
    );

/// Copie un lien dans le presse-papiers (remplacer par share_plus si tu veux la feuille de partage native).
Future<void> copyLink(BuildContext c, String path) async {
  await Clipboard.setData(ClipboardData(text: '${Brand.baseUrl}/$path'));
  if (c.mounted) toast(c, 'Lien copié');
}

Future<void> pickReaction(BuildContext c, Post p) => showModalBottomSheet(
      context: c,
      backgroundColor: C.bubble,
      builder: (s) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, mainAxisSize: MainAxisSize.min, children: [
            for (final e in reactionEmojis)
              GestureDetector(
                onTap: () {
                  app.react(p, e);
                  Navigator.pop(s);
                },
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: p.myReaction == e ? BoxDecoration(color: C.greenPill, shape: BoxShape.circle) : null,
                  child: Text(e, style: TextStyle(fontSize: 30)),
                ),
              ),
          ]),
        ),
      ),
    );

Future<void> showReportSheet(BuildContext c, Channel ch) => showModalBottomSheet(
      context: c,
      backgroundColor: C.bubble,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.all(16), child: Text('Signaler cette boutique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          for (final r in ['Arnaque / faux compte', 'Produit contrefait ou interdit', 'Contenu inapproprié', 'Spam', 'Autre'])
            ListTile(
              title: Text(r),
              onTap: () {
                app.report(ch, r);
                Navigator.pop(s);
                toast(c, 'Signalement envoyé. Merci.');
              },
            ),
        ]),
      ),
    );

/// Menu d'actions sur une publication (appui long).
void showPostOptions(BuildContext context, Channel ch, Post p) {
  showModalBottomSheet(
    context: context,
    backgroundColor: C.bubble,
    builder: (s) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.all(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final e in reactionEmojis)
              GestureDetector(onTap: () { app.react(p, e); Navigator.pop(s); }, child: Text(e, style: TextStyle(fontSize: 28))),
          ]),
        ),
        ListTile(leading: Icon(Icons.shortcut), title: Text('Partager'), onTap: () { Navigator.pop(s); copyLink(context, 'p/${p.id}'); }),
        if (p.isProduct)
          ListTile(
            leading: Icon(app.favorites.contains(p.id) ? Icons.favorite : Icons.favorite_border),
            title: Text(app.favorites.contains(p.id) ? 'Retirer des favoris' : 'Ajouter aux favoris'),
            onTap: () { Navigator.pop(s); app.toggleFavorite(p); },
          ),
        if (ch.mine) ...[
          if (p.isProduct) ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modifier'), onTap: () { Navigator.pop(s); Navigator.push(context, MaterialPageRoute(builder: (_) => PublishProductScreen(channel: ch, editing: p))); }),
          if (p.isProduct) ListTile(leading: Icon(Icons.block), title: Text(p.sold ? 'Marquer disponible' : 'Marquer terminé'), onTap: () { Navigator.pop(s); app.toggleSold(p); }),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(s);
              if (await confirmDialog(context, 'Supprimer cette publication ?', 'Cette action est définitive.', ok: 'Supprimer', danger: true)) app.deletePost(ch, p);
            },
          ),
        ],
      ]),
    ),
  );
}
