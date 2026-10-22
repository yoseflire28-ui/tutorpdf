enum TutorPDFThemeMode { system, light, dark }

class AppSettings {
  final TutorPDFThemeMode themeMode;
  final bool fontRefinement;
  final double brightnessLevel;
  final bool keepScreenOn;
  final String languageCode;
  final double defaultZoom;

  const AppSettings({
    this.themeMode = TutorPDFThemeMode.system,
    this.fontRefinement = true,
    this.brightnessLevel = 0.92,
    this.keepScreenOn = false,
    this.languageCode = 'en',
    this.defaultZoom = 1.0,
  });

  AppSettings copyWith({
    TutorPDFThemeMode? themeMode,
    bool? fontRefinement,
    double? brightnessLevel,
    bool? keepScreenOn,
    String? languageCode,
    double? defaultZoom,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fontRefinement: fontRefinement ?? this.fontRefinement,
      brightnessLevel: brightnessLevel ?? this.brightnessLevel,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      languageCode: languageCode ?? this.languageCode,
      defaultZoom: defaultZoom ?? this.defaultZoom,
    );
  }
}
