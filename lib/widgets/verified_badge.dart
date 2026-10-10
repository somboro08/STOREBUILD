import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Icon(Icons.verified, size: size, color: C.link);
}

/// Nom de boutique + badge si vérifiée.
class ChannelTitle extends StatelessWidget {
  final Channel channel;
  final TextStyle? style;
  const ChannelTitle(this.channel, {super.key, this.style});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        if (channel.verified) ...[SizedBox(width: 4), VerifiedBadge(size: (style?.fontSize ?? 16) * .95)],
      ]);
}

/// "★ 4.6 (12 avis)" ou "Pas encore d'avis".
class RatingLine extends StatelessWidget {
  final Channel channel;
  final String? postId;
  final double size;
  const RatingLine(this.channel, {super.key, this.postId, this.size = 14});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final r = app.ratingOf(channel, postId: postId);
          final n = app.reviewsOf(channel, postId: postId).length;
          if (r == null) return Text('Pas encore d\'avis', style: TextStyle(color: C.sub, fontSize: size));
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star, size: size + 2, color: Colors.amber),
            SizedBox(width: 3),
            Text('${r.toStringAsFixed(1)} ($n avis)', style: TextStyle(fontSize: size)),
          ]);
        },
      );
}
