import 'package:flutter/material.dart';

class TutorPDFColors {
  static const Color background = Color(0xFFEFE7DC); // Cream / Beige (Main Screen Canvas / Light Background)
  static const Color darkBackground = Color(0xFF1E1E1E); // Dark Background (Behind Cards in Dark Mode)
  static const Color accent = Color(0xFFE65A4B); // Coral Red (Accents, Active Icons, Buttons, Highlights)
  static const Color surfaceCard = Color(0xFF3D3D3F); // Dark Charcoal (Content Cards, Reader Containers, Drawer Surfaces)
  static const Color foreground = Color(0xFFF9F6F0); // Off-White (Text on Dark Charcoal, Icons, Foreground Labels)
  static const Color neutral = Color(0xFF9D9A91);
  static const Color border = Color(0xFFBDB6AD);
  static const Color danger = Color(0xFFB00020);
}

class TutorPDFTextStyles {
  static const TextStyle headline = TextStyle(
    color: TutorPDFColors.foreground,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.15,
  );

  static const TextStyle title = TextStyle(
    color: TutorPDFColors.foreground,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: TutorPDFColors.foreground,
    fontSize: 14,
    height: 1.45,
  );
}

extension TutorPDFThemeExtension on ThemeData {
  Color get tutorPDFBackground => colorScheme.surface;
  Color get tutorPDFAccent => colorScheme.primary;
  Color get tutorPDFSurface => colorScheme.surface;
  Color get tutorPDFForeground => colorScheme.onSurface;
  Color get tutorPDFCard => colorScheme.surfaceContainerHighest;
}

class TutorPDFTheme {
  static ThemeData light({required double brightnessLevel}) {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: TutorPDFColors.accent,
        onPrimary: TutorPDFColors.foreground,
        secondary: TutorPDFColors.accent,
        onSecondary: TutorPDFColors.foreground,
        surface: TutorPDFColors.surfaceCard,
        onSurface: TutorPDFColors.foreground,
        error: TutorPDFColors.danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: TutorPDFColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: TutorPDFColors.surfaceCard,
        foregroundColor: TutorPDFColors.foreground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: TutorPDFColors.foreground),
        titleTextStyle: TextStyle(
          color: TutorPDFColors.foreground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardColor: TutorPDFColors.surfaceCard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TutorPDFColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: TutorPDFColors.border.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TutorPDFColors.accent),
        ),
        hintStyle: const TextStyle(color: Color(0xFFB8B0A3)),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: TutorPDFTextStyles.headline,
        titleMedium: TutorPDFTextStyles.title,
        bodyMedium: TutorPDFTextStyles.body,
      ),
      iconTheme: const IconThemeData(color: TutorPDFColors.foreground),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TutorPDFColors.accent,
          foregroundColor: TutorPDFColors.foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: TutorPDFColors.accent,
        thumbColor: TutorPDFColors.accent,
        inactiveTrackColor: TutorPDFColors.foreground.withValues(alpha: 0.4),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: TutorPDFColors.surfaceCard),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TutorPDFColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      brightness: Brightness.light,
      visualDensity: VisualDensity.adaptivePlatformDensity, dialogTheme: DialogThemeData(backgroundColor: TutorPDFColors.surfaceCard),
    );
  }

  static ThemeData dark({required double brightnessLevel}) {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: TutorPDFColors.accent,
        onPrimary: TutorPDFColors.foreground,
        secondary: TutorPDFColors.accent,
        onSecondary: TutorPDFColors.foreground,
        surface: TutorPDFColors.surfaceCard,
        onSurface: TutorPDFColors.foreground,
        error: TutorPDFColors.danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: TutorPDFColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: TutorPDFColors.surfaceCard,
        foregroundColor: TutorPDFColors.foreground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: TutorPDFColors.foreground),
        titleTextStyle: TextStyle(
          color: TutorPDFColors.foreground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardColor: TutorPDFColors.surfaceCard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F1F21),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: TutorPDFColors.border.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TutorPDFColors.accent),
        ),
        hintStyle: const TextStyle(color: Color(0xFFB8B0A3)),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: TutorPDFTextStyles.headline,
        titleMedium: TutorPDFTextStyles.title,
        bodyMedium: TutorPDFTextStyles.body,
      ),
      iconTheme: const IconThemeData(color: TutorPDFColors.foreground),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TutorPDFColors.accent,
          foregroundColor: TutorPDFColors.foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: TutorPDFColors.accent,
        thumbColor: TutorPDFColors.accent,
      ),
      brightness: Brightness.dark,
      visualDensity: VisualDensity.adaptivePlatformDensity, dialogTheme: DialogThemeData(backgroundColor: TutorPDFColors.surfaceCard),
    );
  }
}
