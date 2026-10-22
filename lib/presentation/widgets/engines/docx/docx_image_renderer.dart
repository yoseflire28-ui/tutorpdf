import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

class DocxImage extends DocxNode {
  final String imagePath;
  final Size size; // In points
  
  DocxImage({required this.imagePath, required this.size});
}

class DocxImageRenderer extends StatelessWidget {
  final DocxImage image;
  final Map<String, Uint8List> media;

  const DocxImageRenderer({super.key, required this.image, required this.media});

  @override
  Widget build(BuildContext context) {
    final bytes = media[image.imagePath];
    if (bytes == null) return const SizedBox.shrink();
    
    return Image.memory(
      bytes,
      width: image.size.width,
      height: image.size.height,
      fit: BoxFit.contain,
    );
  }
}
