import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Empreinte visuelle d'une photo pour la recherche par photo.
/// Implémentation par défaut : couleurs + disposition (rapide, sans modèle, hors-ligne). Elle suggère les produits les
/// plus ressemblants mais ne distingue pas bien deux produits de même couleur et même forme.
/// Pour une meilleure précision, écris un ImageEmbedder basé sur un modèle (MobileNet / CLIP en TFLite) et affecte-le
/// à `imageEmbedder` : le reste de l'app (stockage des empreintes, classement) n'a pas à changer.
abstract class ImageEmbedder {
  Future<List<double>> embed(Uint8List bytes);
  double similarity(List<double> a, List<double> b);
}

const _histBins = 28;

List<double> embedBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const [];
  final im = img.copyResize(img.bakeOrientation(decoded), width: 32, height: 32, interpolation: img.Interpolation.average);
  final hist = List<double>.filled(_histBins, 0);
  final grid = List<double>.filled(64, 0);
  final cnt = List<int>.filled(64, 0);
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 32; x++) {
      final p = im.getPixel(x, y);
      final r = p.r / 255, g = p.g / 255, b = p.b / 255;
      final mx = max(r, max(g, b)), mn = min(r, min(g, b));
      final d = mx - mn;
      final sat = mx == 0 ? 0.0 : d / mx;
      int bin;
      if (sat < 0.18 || mx < 0.15) {
        bin = 24 + min(3, (mx * 4).floor());
      } else {
        double h;
        if (mx == r) {
          h = ((g - b) / d) % 6;
        } else if (mx == g) {
          h = (b - r) / d + 2;
        } else {
          h = (r - g) / d + 4;
        }
        bin = min(11, (h * 2).floor()) * 2 + (mx < 0.55 ? 0 : 1);
      }
      hist[bin] += 1;
      final gi = (y ~/ 4) * 8 + (x ~/ 4);
      grid[gi] += 0.299 * r + 0.587 * g + 0.114 * b;
      cnt[gi]++;
    }
  }
  for (var i = 0; i < hist.length; i++) {
    hist[i] /= 1024;
  }
  var mean = 0.0;
  for (var i = 0; i < 64; i++) {
    grid[i] = cnt[i] == 0 ? 0 : grid[i] / cnt[i];
    mean += grid[i] / 64;
  }
  for (var i = 0; i < 64; i++) {
    grid[i] -= mean;
  }
  return [...hist, ...grid];
}

double _cos(List<double> a, List<double> b, int from, int to) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = from; i < to; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (sqrt(na) * sqrt(nb));
}

class ColorLayoutEmbedder implements ImageEmbedder {
  @override
  Future<List<double>> embed(Uint8List bytes) => compute(embedBytes, bytes);

  @override
  double similarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.length < _histBins + 64) return 0;
    final color = _cos(a, b, 0, _histBins);
    final layout = (_cos(a, b, _histBins, a.length) + 1) / 2;
    return 0.6 * color + 0.4 * layout;
  }
}

ImageEmbedder imageEmbedder = ColorLayoutEmbedder();
