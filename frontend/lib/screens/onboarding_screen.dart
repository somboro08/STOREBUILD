import 'package:flutter/material.dart';
import '../brand.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';

class _Page {
  final IconData icon;
  final String title, body;
  const _Page(this.icon, this.title, this.body);
}

/// Présentation affichée à la première ouverture (3 écrans).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ctrl = PageController();
  int page = 0;

  static const pages = [
    _Page(Icons.storefront_outlined, 'Découvre des boutiques', 'Suis tes boutiques préférées et vois leurs nouveaux produits dès leur publication.'),
    _Page(Icons.manage_search, 'Trouve vite ce qu\'il te faut', 'Recherche et filtre par catégorie ou par prix, au lieu de remonter des dizaines de messages.'),
    _Page(Icons.phone_android, 'Paie en mobile money', 'MTN MoMo, Moov Money, Celtiis Cash. Tu as des produits à vendre ? Ouvre ta propre boutique en quelques secondes.'),
  ];

  @override
  Widget build(BuildContext context) {
    final last = page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(children: [
              BrandLogo(size: 34),
              SizedBox(width: 10),
              Text(Brand.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Spacer(),
              if (!last) TextButton(onPressed: app.finishOnboarding, child: Text('Passer', style: TextStyle(color: C.sub))),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: ctrl,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => page = i),
              itemBuilder: (_, i) {
                final p = pages[i];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 170, height: 170,
                      decoration: BoxDecoration(color: C.greenPill, shape: BoxShape.circle),
                      child: Icon(p.icon, size: 82, color: C.green),
                    ),
                    SizedBox(height: 40),
                    Text(p.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    SizedBox(height: 14),
                    Text(p.body, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.4, color: C.sub)),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < pages.length; i++)
              AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: i == page ? 24 : 8, height: 8,
                decoration: BoxDecoration(color: i == page ? C.green : C.chip, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.black, minimumSize: Size.fromHeight(54)),
              onPressed: () => last ? app.finishOnboarding() : ctrl.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeOut),
              child: Text(last ? 'Commencer' : 'Suivant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
