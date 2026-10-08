import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'media_viewer_screen.dart';

/// Médias et liens d'une chaîne.
class MediaGalleryScreen extends StatelessWidget {
  final Channel channel;
  const MediaGalleryScreen({super.key, required this.channel});
  @override
  Widget build(BuildContext context) {
    final media = channel.posts.where((p) => p.type != PostType.text).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(channel.name, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
          bottom: TabBar(indicatorColor: C.green, labelColor: C.green, unselectedLabelColor: C.sub, tabs: [Tab(text: 'Médias'), Tab(text: 'Liens')]),
        ),
        body: TabBarView(children: [
          media.isEmpty
              ? Center(child: Text('Aucun média', style: TextStyle(color: C.sub)))
              : GridView.count(
                  crossAxisCount: 3, mainAxisSpacing: 3, crossAxisSpacing: 3,
                  children: [
                    for (final p in media)
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewerScreen(channel: channel, post: p))),
                        child: ProductImage(color: p.color, bytes: p.bytes),
                      ),
                  ],
                ),
          Center(child: Text('Aucun lien', style: TextStyle(color: C.sub))),
        ]),
      ),
    );
  }
}
