import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../data.dart';
import '../theme.dart';
import 'avatar.dart';

class PostBubble extends StatelessWidget {
  final Post post;
  final String channelName;
  final VoidCallback onTapMedia;
  final VoidCallback? onAddToCart;
  const PostBubble({super.key, required this.post, required this.channelName, required this.onTapMedia, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final hasMedia = post.type != PostType.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(hasMedia ? 4 : 0),
          decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (post.quote != null) _quote(),
            if (hasMedia) _media(),
            Padding(
              padding: EdgeInsets.fromLTRB(hasMedia ? 8 : 12, hasMedia ? 8 : 10, hasMedia ? 8 : 12, 0),
              child: _body(),
            ),
            if (post.isProduct && !post.sold && onAddToCart != null)
              Padding(
                padding: EdgeInsets.fromLTRB(hasMedia ? 8 : 12, 10, hasMedia ? 8 : 12, 0),
                child: Row(children: [
                  Expanded(
                    child: Text('${fmtInt(post.price!)} FCFA${post.category != null ? ' · ${post.category}' : ''}',
                        style: const TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAddToCart,
                    icon: const Icon(Icons.add_shopping_cart, size: 17),
                    label: const Text('Ajouter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.green,
                      side: const BorderSide(color: C.green),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 2, hasMedia ? 8 : 12, hasMedia ? 4 : 8),
                child: Text(post.time, style: const TextStyle(color: C.sub, fontSize: 12)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 5),
        Row(children: [
          if (post.reactions.isNotEmpty) ...[
            _chip(Row(mainAxisSize: MainAxisSize.min, children: [
              Text(post.reactions.join(' '), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text('${post.reactionCount}', style: const TextStyle(color: C.sub, fontSize: 13)),
            ])),
            const SizedBox(width: 6),
          ],
          if (post.forwards > 0 || post.reactions.isNotEmpty)
            _chip(Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shortcut, size: 17, color: C.sub),
              const SizedBox(width: 5),
              Text('${post.forwards}', style: const TextStyle(color: C.sub, fontSize: 13)),
            ])),
        ]),
      ]),
    );
  }

  Widget _chip(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A3942), width: .8)),
        child: child,
      );

  Widget _quote() => Container(
        margin: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: const Color(0xFF16222A),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: C.link, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(channelName, style: const TextStyle(color: C.link, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.image_outlined, size: 14, color: C.sub),
            const SizedBox(width: 4),
            Expanded(child: Text(post.quote!, style: const TextStyle(color: C.sub, fontSize: 14))),
          ]),
        ]),
      );

  Widget _media() {
    final video = post.type == PostType.video;
    return GestureDetector(
      onTap: onTapMedia,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(alignment: Alignment.center, children: [
          ProductImage(color: post.color, bytes: post.bytes, height: video ? 360 : 200),
          if (video)
            Container(
              width: 54, height: 54,
              decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, size: 36),
            ),
          if (video)
            Positioned(
              left: 8, bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(16)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.file_download_outlined, size: 16), SizedBox(width: 4), Text('6,1 Mo', style: TextStyle(fontSize: 12.5)),
                ]),
              ),
            ),
          if (post.sold)
            Transform.rotate(
              angle: -math.pi / 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Terminé', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'serif')),
                  SizedBox(width: 4),
                  Text('✕✕✕', style: TextStyle(color: Color(0xFFE53935), fontSize: 20, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _body() {
    final truncated = post.text.endsWith('…');
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: post.text, style: TextStyle(fontSize: 16, height: 1.28, fontWeight: post.bold ? FontWeight.w700 : FontWeight.w400)),
        if (truncated) const TextSpan(text: ' Voir plus', style: TextStyle(color: C.link, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
    );
  }
}
