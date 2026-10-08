import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

/// Coque principale : barre du bas (Actus, Explorer, Commandes, Profil).
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int idx = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: idx, children: [HomeScreen(), ExploreScreen(), OrdersScreen(), ProfileScreen()]),
      bottomNavigationBar: ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final active = app.orders.where((o) => o.active).length;
          return NavigationBar(
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            indicatorColor: C.greenPill,
            height: 68,
            selectedIndex: idx,
            onDestinationSelected: (i) => setState(() => idx = i),
            destinations: [
              NavigationDestination(icon: Icon(Icons.donut_large_outlined), selectedIcon: Icon(Icons.donut_large), label: 'Boutiques'),
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
              NavigationDestination(
                icon: Badge(isLabelVisible: active > 0, label: Text('$active'), backgroundColor: C.green, textColor: Colors.black, child: Icon(Icons.receipt_long_outlined)),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Commandes',
              ),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
            ],
          );
        },
      ),
    );
  }
}
