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
      padding: EdgeInsets.fromLTRB(14, 6, 14, 6),
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
                        style: TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAddToCart,
                    icon: Icon(Icons.add_shopping_cart, size: 17),
                    label: Text('Ajouter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.green,
                      side: BorderSide(color: C.green),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 2, hasMedia ? 8 : 12, hasMedia ? 4 : 8),
                child: Text(post.time, style: TextStyle(color: C.sub, fontSize: 12)),
              ),
            ),
          ]),
        ),
        SizedBox(height: 5),
        Row(children: [
          if (post.reactions.isNotEmpty) ...[
            _chip(Row(mainAxisSize: MainAxisSize.min, children: [
              Text(post.reactions.join(' '), style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text('${post.reactionCount}', style: TextStyle(color: C.sub, fontSize: 13)),
            ])),
            SizedBox(width: 6),
          ],
          if (post.forwards > 0 || post.reactions.isNotEmpty)
            _chip(Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shortcut, size: 17, color: C.sub),
              SizedBox(width: 5),
              Text('${post.forwards}', style: TextStyle(color: C.sub, fontSize: 13)),
            ])),
        ]),
      ]),
    );
  }

  Widget _chip(Widget child) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border, width: .8)),
        child: child,
      );

  Widget _quote() => Container(
        margin: EdgeInsets.fromLTRB(6, 6, 6, 4),
        padding: EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: C.quote,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: C.link, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(channelName, style: TextStyle(color: C.link, fontWeight: FontWeight.w600, fontSize: 13)),
          SizedBox(height: 2),
          Row(children: [
            Icon(Icons.image_outlined, size: 14, color: C.sub),
            SizedBox(width: 4),
            Expanded(child: Text(post.quote!, style: TextStyle(color: C.sub, fontSize: 14))),
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
              decoration: BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
              child: Icon(Icons.play_arrow_rounded, size: 36),
            ),
          if (video)
            Positioned(
              left: 8, bottom: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: Color(0x99000000), borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.file_download_outlined, size: 16), SizedBox(width: 4), Text('6,1 Mo', style: TextStyle(fontSize: 12.5)),
                ]),
              ),
            ),
          if (post.sold)
            Transform.rotate(
              angle: -math.pi / 7,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
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
        if (truncated) TextSpan(text: ' Voir plus', style: TextStyle(color: C.link, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
    );
  }
}
