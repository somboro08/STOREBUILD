import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../state.dart';
import '../widgets/avatar.dart';

/// Infos de la chaîne.
class ChannelInfoScreen extends StatefulWidget {
  final Channel channel;
  const ChannelInfoScreen({super.key, required this.channel});
  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  bool silent = true;

  Widget _action(IconData icon, String label, [VoidCallback? onTap]) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Column(children: [
        Container(
          width: 78, height: 46,
          decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(24)),
          child: Icon(icon, size: 22),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ]));

  Widget _row(IconData icon, String title, {String? sub, Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: C.sub, size: 24),
          const SizedBox(width: 24),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16.5)),
              if (sub != null) ...[
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(color: C.sub, fontSize: 14, height: 1.3)),
              ],
            ]),
          ),
          if (trailing != null) trailing,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final media = ch.posts.where((p) => p.type != PostType.text).toList();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(children: [
        Center(child: ChannelAvatar(color: ch.color, name: ch.name, size: 120)),
        const SizedBox(height: 16),
        Center(child: Text(ch.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500))),
        const SizedBox(height: 4),
        Center(child: Text('Chaîne • ${fmtInt(ch.followers)} followers', style: const TextStyle(color: C.sub, fontSize: 15))),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _action(ch.followed ? Icons.check : Icons.add, ch.followed ? 'Suivie' : 'Suivre', () {
            app.toggleFollow(ch);
            setState(() {});
          }),
          _action(Icons.shortcut, 'Transférer'),
          _action(Icons.share_outlined, 'Partager'),
          _action(Icons.search, 'Rechercher'),
        ]),
        const SizedBox(height: 14),
        const Divider(color: C.divider, thickness: 8, height: 8),
        if (ch.created.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Créée le ${ch.created}', style: const TextStyle(color: C.sub, fontSize: 14)),
          ),
        if (ch.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ch.description, style: const TextStyle(fontSize: 15.5, height: 1.35)),
              if (ch.zone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.place_outlined, size: 17, color: C.sub), const SizedBox(width: 6), Expanded(child: Text(ch.zone, style: const TextStyle(color: C.sub, fontSize: 14)))]),
              ],
            ]),
          ),
        const Divider(color: C.divider, thickness: 8, height: 22),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Médias et liens', style: TextStyle(color: C.sub, fontSize: 15)),
            Text('${ch.id == 'martistore' ? 329 : media.length}  ›', style: const TextStyle(color: C.sub, fontSize: 15)),
          ]),
        ),
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 16), children: [
            for (final p in media)
              Container(
                width: 92,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.image_outlined, color: Colors.white38),
              ),
          ]),
        ),
        const Divider(color: C.divider, thickness: 8, height: 26),
        _row(Icons.perm_media_outlined, 'Gérer le stockage', sub: '16,0 Mo'),
        _row(
          Icons.notifications_none,
          'Mode silencieux',
          trailing: Switch(
            value: silent,
            onChanged: (v) => setState(() => silent = v),
            thumbColor: const WidgetStatePropertyAll(Color(0xFF0B141A)),
            thumbIcon: WidgetStatePropertyAll(Icon(Icons.check, color: silent ? C.green : Colors.transparent)),
            trackColor: WidgetStatePropertyAll(silent ? C.green : C.chip),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
        const Divider(color: C.divider, thickness: 8, height: 8),
        _row(Icons.public, 'Chaîne publique', sub: 'N\'importe qui peut trouver cette chaîne et voir tout ce qui y est partagé.'),
        _row(Icons.dialpad, 'Confidentialité du profil',
            sub: 'Pour cette chaîne, la confidentialité de votre profil et de votre numéro de téléphone est renforcée. Appuyez pour en savoir plus.'),
        const SizedBox(height: 24),
      ]),
    );
  }
}
