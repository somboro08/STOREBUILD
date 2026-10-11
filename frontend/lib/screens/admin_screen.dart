import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/helpers.dart';
import '../widgets/verified_badge.dart';
import 'channel_feed_screen.dart';

/// Espace administration (numéros listés dans Brand.adminPhones) : signalements et vérification des boutiques.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Administration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          bottom: TabBar(indicatorColor: C.green, labelColor: C.green, unselectedLabelColor: C.sub, tabs: [Tab(text: 'Signalements'), Tab(text: 'Boutiques')]),
        ),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => TabBarView(children: [
            app.reports.isEmpty
                ? Center(child: Text('Aucun signalement', style: TextStyle(color: C.sub)))
                : ListView(children: [
                    for (final r in app.reports.reversed)
                      ListTile(
                        leading: Icon(Icons.flag_outlined, color: Colors.redAccent),
                        title: Text(app.channelById(r.channelId)?.name ?? r.channelId),
                        subtitle: Text('${r.reason}\npar ${r.by.isEmpty ? 'anonyme' : r.by} · ${fmtDate(r.date)}', style: TextStyle(color: C.sub, fontSize: 12.5)),
                        isThreeLine: true,
                        onTap: () {
                          final c = app.channelById(r.channelId);
                          if (c != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: c)));
                        },
                      ),
                  ]),
            ListView(children: [
              for (final c in app.channels)
                ListTile(
                  leading: ChannelAvatar(color: c.color, name: c.name, bytes: c.logo, url: c.logoUrl, size: 44),
                  title: ChannelTitle(c, style: TextStyle(fontSize: 16)),
                  subtitle: Text('${fmtInt(c.followers)} abonnés · ${app.reports.where((r) => r.channelId == c.id).length} signalement(s)', style: TextStyle(color: C.sub, fontSize: 12.5)),
                  trailing: Switch(value: c.verified, activeColor: C.green, onChanged: (v) => app.setVerified(c, v)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
