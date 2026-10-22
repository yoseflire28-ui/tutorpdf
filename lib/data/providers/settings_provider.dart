import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _kIsDarkMode = 'tutorpdf_is_dark_mode';
  static const String _kFontRefinement = 'tutorpdf_font_refinement';
  static const String _kBrightnessLevel = 'tutorpdf_brightness_level';
  static const String _kKeepScreenOn = 'tutorpdf_keep_screen_on';
  static const String _kLanguageCode = 'tutorpdf_language_code';
  static const String _kDefaultZoom = 'tutorpdf_default_zoom';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool _isDarkMode = false;
  bool _fontRefinement = true;
  double _brightnessLevel = -1.0; // -1.0 indicates use system default
  bool _keepScreenOn = false;
  String _languageCode = 'en';
  double _defaultZoom = 1.0;

  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _isDarkMode;
  bool get fontRefinement => _fontRefinement;
  double get brightnessLevel => _brightnessLevel;
  bool get keepScreenOn => _keepScreenOn;
  String get languageCode => _languageCode;
  double get defaultZoom => _defaultZoom;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      _isDarkMode = _prefs?.getBool(_kIsDarkMode) ?? false;
      _fontRefinement = _prefs?.getBool(_kFontRefinement) ?? true;
      _brightnessLevel = _prefs?.getDouble(_kBrightnessLevel) ?? -1.0;
      _keepScreenOn = _prefs?.getBool(_kKeepScreenOn) ?? false;
      _languageCode = _prefs?.getString(_kLanguageCode) ?? 'en';
      _defaultZoom = _prefs?.getDouble(_kDefaultZoom) ?? 1.0;

      _isInitialized = true;
      
      // Apply hardware integrations
      await _applyKeepScreenOn();
      // Only apply brightness if user has explicitly set it (not -1.0 which means system default)
      // This prevents forcing any brightness on app startup
      if (_brightnessLevel >= 0.0) {
        await _applyBrightness();
      } else {
        debugPrint('Brightness: Using system default (not forcing any brightness)');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> updateSettingParam(String key, dynamic value) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      switch (key) {
        case 'isDarkMode':
          _isDarkMode = value as bool;
          await _prefs?.setBool(_kIsDarkMode, _isDarkMode);
          debugPrint('Theme mode updated to: ${_isDarkMode ? "Dark" : "Light"}');
          break;
        case 'fontRefinement':
          _fontRefinement = value as bool;
          await _prefs?.setBool(_kFontRefinement, _fontRefinement);
          break;
        case 'brightnessLevel':
          _brightnessLevel = (value as num).toDouble().clamp(0.0, 1.0);
          await _prefs?.setDouble(_kBrightnessLevel, _brightnessLevel);
          // Only apply brightness if value is >= 0 (not system default)
          if (_brightnessLevel >= 0.0) {
            await _applyBrightness();
          } else {
            debugPrint('Brightness: Reset to system default');
          }
          break;
        case 'keepScreenOn':
          _keepScreenOn = value as bool;
          await _prefs?.setBool(_kKeepScreenOn, _keepScreenOn);
          await _applyKeepScreenOn();
          break;
        case 'languageCode':
          _languageCode = value as String;
          await _prefs?.setString(_kLanguageCode, _languageCode);
          break;
        case 'defaultZoom':
          _defaultZoom = (value as num).toDouble().clamp(0.5, 3.0);
          await _prefs?.setDouble(_kDefaultZoom, _defaultZoom);
          break;
        default:
          debugPrint('Unknown setting key: $key');
          return;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating setting parameter $key: $e');
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
      debugPrint('Wakelock integration error: $e');
    }
  }

  Future<void> _applyBrightness() async {
    try {
      // Clamp brightness to safe range (0.1 to 1.0) to prevent screen going completely dark
      final safeBrightness = _brightnessLevel.clamp(0.1, 1.0);
      await ScreenBrightness().setScreenBrightness(safeBrightness);
      debugPrint('Brightness set to: ${(safeBrightness * 100).toInt()}%');
    } catch (e) {
      debugPrint('Screen brightness hardware integration error: $e');
    }
  }

  Future<void> resetToDefaults() async {
    try {
      _isDarkMode = false;
      _fontRefinement = true;
      _brightnessLevel = -1.0; // Use system default
      _keepScreenOn = false;
      _languageCode = 'en';
      _defaultZoom = 1.0;

      if (_prefs != null) {
        await _prefs!.setBool(_kIsDarkMode, false);
        await _prefs!.setBool(_kFontRefinement, true);
        await _prefs!.setDouble(_kBrightnessLevel, -1.0);
        await _prefs!.setBool(_kKeepScreenOn, false);
        await _prefs!.setString(_kLanguageCode, 'en');
        await _prefs!.setDouble(_kDefaultZoom, 1.0);
      }

      await _applyKeepScreenOn();
      // Reset brightness to system default by not calling _applyBrightness when level is -1.0
      debugPrint('Brightness reset to system default');
      notifyListeners();
    } catch (e) {
      debugPrint('Error resetting settings to defaults: $e');
    }
  }

  /// Convenience method to toggle dark/light theme
  Future<void> toggleTheme() async {
    await updateSettingParam('isDarkMode', !_isDarkMode);
  }
}
