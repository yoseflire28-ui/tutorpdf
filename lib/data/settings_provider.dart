import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum AppThemeMode { light, dark }

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  
  bool _isInitialized = false;
  AppThemeMode _themeMode = AppThemeMode.light;
  bool _highQualityFontRendering = true;
  double _brightness = 1.0;
  bool _keepScreenOn = false;
  String _localization = 'en';
  double _defaultViewportZoom = 1.0;

  bool get isInitialized => _isInitialized;
  AppThemeMode get themeMode => _themeMode;
  bool get highQualityFontRendering => _highQualityFontRendering;
  double get brightness => _brightness;
  bool get keepScreenOn => _keepScreenOn;
  String get localization => _localization;
  double get defaultViewportZoom => _defaultViewportZoom;

  Future<void> initSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      _themeMode = AppThemeMode.values[
          _prefs?.getInt('theme_mode') ?? AppThemeMode.light.index];
      _highQualityFontRendering = 
          _prefs?.getBool('high_quality_font_rendering') ?? true;
      _brightness = _prefs?.getDouble('brightness') ?? 1.0;
      _keepScreenOn = _prefs?.getBool('keep_screen_on') ?? false;
      _localization = _prefs?.getString('localization') ?? 'en';
      _defaultViewportZoom = _prefs?.getDouble('default_viewport_zoom') ?? 1.0;
      
      _isInitialized = true;
      
      await _applyKeepScreenOn();
      
      notifyListeners();
    } catch (e) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      _themeMode = mode;
      await _prefs?.setInt('theme_mode', mode.index);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> setHighQualityFontRendering(bool value) async {
    try {
      _highQualityFontRendering = value;
      await _prefs?.setBool('high_quality_font_rendering', value);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> setBrightness(double value) async {
    try {
      _brightness = value.clamp(0.0, 1.0);
      await _prefs?.setDouble('brightness', _brightness);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> setKeepScreenOn(bool value) async {
    try {
      _keepScreenOn = value;
      await _prefs?.setBool('keep_screen_on', value);
      await _applyKeepScreenOn();
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _applyKeepScreenOn() async {
    try {
      if (_keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> setLocalization(String languageCode) async {
    try {
      _localization = languageCode;
      await _prefs?.setString('localization', languageCode);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> setDefaultViewportZoom(double zoom) async {
    try {
      _defaultViewportZoom = zoom.clamp(0.5, 3.0);
      await _prefs?.setDouble('default_viewport_zoom', _defaultViewportZoom);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> resetToDefaults() async {
    try {
      _themeMode = AppThemeMode.light;
      _highQualityFontRendering = true;
      _brightness = 1.0;
      _keepScreenOn = false;
      _localization = 'en';
      _defaultViewportZoom = 1.0;

      await _prefs?.setInt('theme_mode', AppThemeMode.light.index);
      await _prefs?.setBool('high_quality_font_rendering', true);
      await _prefs?.setDouble('brightness', 1.0);
      await _prefs?.setBool('keep_screen_on', false);
      await _prefs?.setString('localization', 'en');
      await _prefs?.setDouble('default_viewport_zoom', 1.0);

      await _applyKeepScreenOn();
      
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> clearAllSettings() async {
    try {
      await _prefs?.clear();
      await resetToDefaults();
    } catch (e) {
      // Handle error silently
    }
  }
}
