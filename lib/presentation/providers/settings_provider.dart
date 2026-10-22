import 'package:flutter/material.dart';
import '../../domain/app_settings.dart';
import '../../services/app_settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final AppSettingsService _service;
  AppSettings _settings;
  bool _initialized = false;

  SettingsProvider({required AppSettingsService service, AppSettings? initialSettings})
      : _service = service,
        _settings = initialSettings ?? const AppSettings();

  AppSettings get settings => _settings;
  bool get initialized => _initialized;

  Future<void> load() async {
    _settings = await _service.loadSettings();
    _initialized = true;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _service.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateThemeMode(TutorPDFThemeMode mode) async {
    await updateSettings(_settings.copyWith(themeMode: mode));
  }

  Future<void> updateFontRefinement(bool enabled) async {
    await updateSettings(_settings.copyWith(fontRefinement: enabled));
  }

  Future<void> updateBrightness(double value) async {
    await updateSettings(_settings.copyWith(brightnessLevel: value));
  }

  Future<void> updateKeepScreenOn(bool keepOn) async {
    await updateSettings(_settings.copyWith(keepScreenOn: keepOn));
  }

  Future<void> updateLanguage(String code) async {
    await updateSettings(_settings.copyWith(languageCode: code));
  }

  Future<void> updateDefaultZoom(double zoom) async {
    await updateSettings(_settings.copyWith(defaultZoom: zoom));
  }
}
