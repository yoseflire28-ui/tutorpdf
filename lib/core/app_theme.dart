import 'package:flutter/material.dart';

class AppTheme {
  // Global Color Palette - Exact Hex Codes
  static const Color coralAccent = Color(0xFFE65A4B); // Coral Red (Accents, Active Icons, Buttons, Highlights)
  static const Color charcoalCard = Color(0xFF3D3D3F); // Dark Charcoal (Content Cards, Reader Containers, Drawer Surfaces)
  static const Color offWhiteText = Color(0xFFF5F5F5); // High-Contrast White/Off-White (Text on Dark Charcoal, Icons, Foreground Labels)
  static const Color creamBackground = Color(0xFFEFE7DC); // Cream / Beige (Main Screen Canvas / Light Background)
  static const Color darkBackground = Color(0xFF1A1A1A); // Deep Off-Black (Background Canvas in Dark Mode)

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamBackground,
      colorScheme: const ColorScheme.light(
        primary: coralAccent,
        secondary: coralAccent,
        surface: charcoalCard,
        onSurface: offWhiteText,
        error: coralAccent,
        onError: offWhiteText,
      ),
      cardColor: charcoalCard,
      dividerColor: coralAccent.withValues(alpha: 0.2),
      popupMenuTheme: const PopupMenuThemeData(
        color: charcoalCard,
        textStyle: TextStyle(color: offWhiteText),
        iconColor: coralAccent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: coralAccent.withValues(alpha: 0.4),
        selectionHandleColor: coralAccent,
        cursorColor: coralAccent,
      ),
      textTheme: _buildTextTheme(charcoalCard).apply(fontFamily: 'Roboto'),
      primaryTextTheme: _buildTextTheme(offWhiteText).apply(fontFamily: 'Roboto'),
      appBarTheme: const AppBarTheme(
        backgroundColor: charcoalCard,
        foregroundColor: offWhiteText,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: offWhiteText),
        titleTextStyle: TextStyle(
          color: offWhiteText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: charcoalCard,
        selectedItemColor: coralAccent,
        unselectedItemColor: offWhiteText,
        selectedLabelStyle: TextStyle(
          color: coralAccent,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          color: offWhiteText,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: coralAccent,
        foregroundColor: offWhiteText,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coralAccent,
          foregroundColor: offWhiteText,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: coralAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: coralAccent,
          side: const BorderSide(color: coralAccent, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: charcoalCard,
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(
        color: offWhiteText,
        size: 24,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent;
          }
          return offWhiteText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent.withValues(alpha: 0.5);
          }
          return charcoalCard.withValues(alpha: 0.5);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(offWhiteText),
        side: const BorderSide(color: coralAccent, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent;
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.all(coralAccent.withValues(alpha: 0.1)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: coralAccent,
        inactiveTrackColor: charcoalCard,
        thumbColor: coralAccent,
        overlayColor: coralAccent,
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: charcoalCard,
        selectedColor: coralAccent,
        labelStyle: const TextStyle(color: offWhiteText),
        secondaryLabelStyle: const TextStyle(color: offWhiteText),
        brightness: Brightness.dark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: coralAccent.withValues(alpha: 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamBackground.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: coralAccent.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent, width: 2),
        ),
        labelStyle: const TextStyle(color: charcoalCard),
        hintStyle: TextStyle(color: charcoalCard.withValues(alpha: 0.6)),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return coralAccent;
          }
          return charcoalCard.withValues(alpha: 0.7);
        }),
        suffixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return coralAccent;
          }
          return charcoalCard.withValues(alpha: 0.7);
        }),
      ),
      cardTheme: const CardThemeData(
        color: charcoalCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: EdgeInsets.all(8),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: offWhiteText,
        textColor: offWhiteText,
        tileColor: charcoalCard,
        selectedTileColor: coralAccent.withValues(alpha: 0.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        elevation: 8,
        titleTextStyle: TextStyle(
          color: offWhiteText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: offWhiteText,
          fontSize: 16,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: charcoalCard,
        contentTextStyle: const TextStyle(color: offWhiteText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: coralAccent,
        unselectedLabelColor: offWhiteText,
        indicatorColor: coralAccent,
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: coralAccent,
        linearTrackColor: charcoalCard,
        circularTrackColor: charcoalCard,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: charcoalCard,
      colorScheme: const ColorScheme.dark(
        primary: charcoalCard,
        secondary: coralAccent,
        surface: charcoalCard,
        onSurface: offWhiteText,
        error: coralAccent,
        onError: offWhiteText,
      ),
      cardColor: charcoalCard,
      dividerColor: coralAccent.withValues(alpha: 0.2),
      popupMenuTheme: const PopupMenuThemeData(
        color: charcoalCard,
        textStyle: TextStyle(color: offWhiteText),
        iconColor: coralAccent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: coralAccent.withValues(alpha: 0.4),
        selectionHandleColor: coralAccent,
        cursorColor: coralAccent,
      ),
      textTheme: _buildTextTheme(offWhiteText).apply(fontFamily: 'Roboto'),
      primaryTextTheme: _buildTextTheme(offWhiteText).apply(fontFamily: 'Roboto'),
      appBarTheme: const AppBarTheme(
        backgroundColor: charcoalCard,
        foregroundColor: offWhiteText,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: coralAccent),
        titleTextStyle: TextStyle(
          color: offWhiteText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: charcoalCard,
        selectedItemColor: coralAccent,
        unselectedItemColor: offWhiteText,
        selectedLabelStyle: TextStyle(
          color: coralAccent,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          color: offWhiteText,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: coralAccent,
        foregroundColor: offWhiteText,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coralAccent,
          foregroundColor: offWhiteText,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: coralAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: coralAccent,
          side: const BorderSide(color: coralAccent, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: offWhiteText,
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(
        color: offWhiteText,
        size: 24,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent;
          }
          return offWhiteText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent.withValues(alpha: 0.5);
          }
          return creamBackground.withValues(alpha: 0.5);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(offWhiteText),
        side: const BorderSide(color: coralAccent, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coralAccent;
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.all(coralAccent.withValues(alpha: 0.1)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: coralAccent,
        inactiveTrackColor: creamBackground,
        thumbColor: coralAccent,
        overlayColor: coralAccent,
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamBackground,
        selectedColor: coralAccent,
        labelStyle: const TextStyle(color: offWhiteText),
        secondaryLabelStyle: const TextStyle(color: offWhiteText),
        brightness: Brightness.dark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: coralAccent.withValues(alpha: 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamBackground.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: coralAccent.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coralAccent, width: 2),
        ),
        labelStyle: const TextStyle(color: offWhiteText),
        hintStyle: TextStyle(color: offWhiteText.withValues(alpha: 0.6)),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return coralAccent;
          }
          return offWhiteText.withValues(alpha: 0.7);
        }),
        suffixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return coralAccent;
          }
          return offWhiteText.withValues(alpha: 0.7);
        }),
      ),
      cardTheme: const CardThemeData(
        color: creamBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: EdgeInsets.all(8),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: charcoalCard,
        textColor: charcoalCard,
        tileColor: creamBackground,
        selectedTileColor: coralAccent.withValues(alpha: 0.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        elevation: 8,
        titleTextStyle: TextStyle(
          color: offWhiteText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: offWhiteText,
          fontSize: 16,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: charcoalCard,
        contentTextStyle: const TextStyle(color: offWhiteText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: coralAccent,
        unselectedLabelColor: offWhiteText,
        indicatorColor: coralAccent,
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: coralAccent,
        linearTrackColor: creamBackground,
        circularTrackColor: creamBackground,
      ),
    );
  }

  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      displayLarge: TextStyle(
        color: textColor,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        color: textColor,
        fontSize: 45,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: TextStyle(
        color: textColor,
        fontSize: 36,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: TextStyle(
        color: textColor,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: TextStyle(
        color: textColor,
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
