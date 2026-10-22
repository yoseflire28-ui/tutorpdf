import 'package:flutter/material.dart';

/// Parses OOXML color values (e.g., 'auto', 'FF0000', 'theme1') 
/// into Flutter [Color] objects.
class OoxmlColorParser {
  static Color parse(String? colorVal, {Color defaultColor = Colors.black}) {
    if (colorVal == null || colorVal == 'auto') return defaultColor;

    // Handle Hex colors (e.g., 'FF0000', '00FF00')
    if (colorVal.length == 6) {
      try {
        return Color(int.parse('FF$colorVal', radix: 16));
      } catch (_) {
        return defaultColor;
      }
    }
    
    // Additional theme logic can be implemented here as needed
    return defaultColor;
  }
}
