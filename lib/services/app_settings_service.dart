import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';

class AppSettingsService {
  static const _themeModeKey = 'tutorpdf_theme_mode';
  static const _fontRefinementKey = 'tutorpdf_font_refinement';
  static const _brightnessKey = 'tutorpdf_brightness_level';
  static const _wakeLockKey = 'tutorpdf_keep_screen_on';
  static const _languageKey = 'tutorpdf_language_code';
  static const _defaultZoomKey = 'tutorpdf_default_zoom';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? TutorPDFThemeMode.system.index;
    final brightness = prefs.getDouble(_brightnessKey) ?? 0.92;
    final fontRefinement = prefs.getBool(_fontRefinementKey) ?? true;
    final keepOn = prefs.getBool(_wakeLockKey) ?? false;
    final languageCode = prefs.getString(_languageKey) ?? 'en';
    final defaultZoom = prefs.getDouble(_defaultZoomKey) ?? 1.0;

    return AppSettings(
      themeMode: TutorPDFThemeMode.values.elementAt(themeModeIndex),
      brightnessLevel: brightness.clamp(0.2, 1.0),
      fontRefinement: fontRefinement,
      keepScreenOn: keepOn,
      languageCode: languageCode,
      defaultZoom: defaultZoom.clamp(0.5, 3.0),
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, settings.themeMode.index);
    await prefs.setBool(_fontRefinementKey, settings.fontRefinement);
    await prefs.setDouble(_brightnessKey, settings.brightnessLevel);
    await prefs.setBool(_wakeLockKey, settings.keepScreenOn);
    await prefs.setString(_languageKey, settings.languageCode);
    await prefs.setDouble(_defaultZoomKey, settings.defaultZoom);
  }
}
