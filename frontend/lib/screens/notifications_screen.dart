import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';

/// Centre de notifications (commandes, retraits, avis). Les notifications push viendront avec l'API.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => app.readAllNotices());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.notices.isEmpty) return Center(child: Text('Rien de nouveau', style: TextStyle(color: C.sub)));
          return ListView(children: [
            for (final n in app.notices)
              ListTile(
                leading: CircleAvatar(backgroundColor: C.greenPill, child: Icon(Icons.notifications_none, color: C.green)),
                title: Text(n.title),
                subtitle: Text('${n.body}\n${fmtDate(n.date)}', style: TextStyle(color: C.sub, fontSize: 13)),
                isThreeLine: n.body.isNotEmpty,
              ),
          ]);
        },
      ),
    );
  }
}
