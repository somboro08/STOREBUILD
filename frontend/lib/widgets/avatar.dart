import 'dart:typed_data';
import 'package:flutter/material.dart';

class ChannelAvatar extends StatelessWidget {
  final Color color;
  final double size;
  final String name;
  final Uint8List? bytes;
  final String? url;
  const ChannelAvatar({super.key, required this.color, required this.name, this.size = 52, this.bytes, this.url});

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > .6;
    final letter = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(name.isEmpty ? '' : name[0].toUpperCase(),
          style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w600, color: light ? Colors.black87 : Colors.white)),
    );
    if (bytes != null) return ClipOval(child: Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover));
    if (url != null) {
      return ClipOval(child: Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => letter));
    }
    return letter;
  }
}

/// Image produit : photo locale, sinon URL (API), sinon placeholder coloré.
class ProductImage extends StatelessWidget {
  final Color color;
  final double? height;
  final Uint8List? bytes;
  final String? url;
  final BoxFit fit;
  const ProductImage({super.key, required this.color, this.height, this.bytes, this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: color,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: 56, color: Colors.white38),
    );
    if (bytes != null) return SizedBox(height: height, width: double.infinity, child: Image.memory(bytes!, fit: fit));
    if (url != null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: Image.network(url!, fit: fit, errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (c, child, p) => p == null ? child : Container(color: color, alignment: Alignment.center, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return placeholder;
  }
}
