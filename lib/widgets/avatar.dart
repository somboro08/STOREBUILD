import 'dart:typed_data';
import 'package:flutter/material.dart';

class ChannelAvatar extends StatelessWidget {
  final Color color;
  final double size;
  final String name;
  const ChannelAvatar({super.key, required this.color, required this.name, this.size = 52});
  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > .6;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(name.isEmpty ? '' : name[0].toUpperCase(),
          style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w600, color: light ? Colors.black87 : Colors.white)),
    );
  }
}

/// Image produit : photo choisie par le vendeur, sinon placeholder coloré.
/// Pour une API : remplacer par Image.network(url).
class ProductImage extends StatelessWidget {
  final Color color;
  final double? height;
  final Uint8List? bytes;
  const ProductImage({super.key, required this.color, this.height, this.bytes});
  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return SizedBox(height: height, width: double.infinity, child: Image.memory(bytes!, fit: BoxFit.cover));
    }
    return Container(
      height: height,
      width: double.infinity,
      color: color,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: 56, color: Colors.white38),
    );
  }
}
