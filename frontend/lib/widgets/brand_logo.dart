import 'package:flutter/material.dart';

/// Logo Whatstore : bulle de discussion + vitrine de boutique.
/// Même dessin que assets/brand/*.png et logo.svg (grille 2048 x 2048).
class BrandLogo extends StatelessWidget {
  final double size;
  final bool background; // fond vert arrondi (icône) ou bulle seule
  const BrandLogo({super.key, this.size = 96, this.background = true});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _LogoPainter(background));
}

class _LogoPainter extends CustomPainter {
  final bool bg;
  _LogoPainter(this.bg);

  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 2048);
    final white = Paint()..color = Colors.white;
    final green = Paint()..color = Color(0xFF25D366);
    if (bg) c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 2048, 2048), Radius.circular(460)), green);
    c.drawRRect(RRect.fromLTRBR(330, 330, 1718, 1500, Radius.circular(260)), white);
    c.drawPath(Path()..moveTo(420, 1450)..lineTo(420, 1760)..lineTo(760, 1450)..close(), white);
    c.drawRect(Rect.fromLTRB(610, 560, 1438, 720), green);
    for (final cx in [713.5, 920.5, 1127.5, 1334.5]) {
      c.drawCircle(Offset(cx, 720), 103.5, green);
    }
    c.drawRect(Rect.fromLTRB(700, 900, 1348, 1270), green);
    c.drawRect(Rect.fromLTRB(940, 1040, 1108, 1270), white);
    c.drawRect(Rect.fromLTRB(760, 1000, 900, 1150), white);
    c.drawRect(Rect.fromLTRB(1148, 1000, 1288, 1150), white);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.bg != bg;
}
