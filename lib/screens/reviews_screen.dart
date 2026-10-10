import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';
import '../widgets/verified_badge.dart';

/// Avis sur une boutique (ou sur un de ses produits).
class ReviewsScreen extends StatelessWidget {
  final Channel channel;
  final String? postId;
  const ReviewsScreen({super.key, required this.channel, this.postId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Avis · ${channel.name}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = app.reviewsOf(channel, postId: postId);
          return ListView(padding: EdgeInsets.all(16), children: [
            Center(child: RatingLine(channel, postId: postId, size: 18)),
            SizedBox(height: 6),
            Center(child: Text('Les avis viennent des clients dont la commande a été livrée.', textAlign: TextAlign.center, style: TextStyle(color: C.sub, fontSize: 12.5))),
            SizedBox(height: 14),
            if (list.isEmpty) Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Aucun avis pour le moment', style: TextStyle(color: C.sub)))),
            for (final r in list)
              Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.bubble, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.author.isEmpty ? 'Client' : r.author, style: TextStyle(fontWeight: FontWeight.w600))),
                    for (var i = 1; i <= 5; i++) Icon(i <= r.rating ? Icons.star : Icons.star_border, size: 16, color: Colors.amber),
                  ]),
                  if (r.text.isNotEmpty) Padding(padding: EdgeInsets.only(top: 6), child: Text(r.text)),
                  SizedBox(height: 6),
                  Text(fmtDate(r.date), style: TextStyle(color: C.sub, fontSize: 12)),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
