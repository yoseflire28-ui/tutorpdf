import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class AppColors {
  static const Color creamBackground = Color(0xFFEFE7DC);
  static const Color coralAccent = Color(0xFFE65A4B);
  static const Color charcoalCard = Color(0xFF3D3D3F);
  static const Color offWhiteText = Color(0xFFF9F6F0);
}

class TutorPDFTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.creamBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.coralAccent,
        secondary: AppColors.coralAccent,
        surface: AppColors.charcoalCard,
        onSurface: AppColors.offWhiteText,
      ),
      cardColor: AppColors.charcoalCard,
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.charcoalCard),
        displayMedium: TextStyle(color: AppColors.charcoalCard),
        displaySmall: TextStyle(color: AppColors.charcoalCard),
        headlineLarge: TextStyle(color: AppColors.charcoalCard),
        headlineMedium: TextStyle(color: AppColors.charcoalCard),
        headlineSmall: TextStyle(color: AppColors.charcoalCard),
        titleLarge: TextStyle(color: AppColors.charcoalCard),
        titleMedium: TextStyle(color: AppColors.charcoalCard),
        titleSmall: TextStyle(color: AppColors.charcoalCard),
        bodyLarge: TextStyle(color: AppColors.charcoalCard),
        bodyMedium: TextStyle(color: AppColors.charcoalCard),
        bodySmall: TextStyle(color: AppColors.charcoalCard),
        labelLarge: TextStyle(color: AppColors.charcoalCard),
        labelMedium: TextStyle(color: AppColors.charcoalCard),
        labelSmall: TextStyle(color: AppColors.charcoalCard),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.charcoalCard,
        foregroundColor: AppColors.offWhiteText,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.coralAccent,
        foregroundColor: AppColors.offWhiteText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coralAccent,
          foregroundColor: AppColors.offWhiteText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.coralAccent;
          }
          return AppColors.offWhiteText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.coralAccent.withValues(alpha: 0.5);
          }
          return AppColors.charcoalCard.withValues(alpha: 0.5);
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.coralAccent,
        inactiveTrackColor: AppColors.charcoalCard,
        thumbColor: AppColors.coralAccent,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.charcoalCard,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.coralAccent,
        secondary: AppColors.coralAccent,
        surface: AppColors.creamBackground,
        onSurface: AppColors.charcoalCard,
      ),
      cardColor: AppColors.creamBackground,
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.offWhiteText),
        displayMedium: TextStyle(color: AppColors.offWhiteText),
        displaySmall: TextStyle(color: AppColors.offWhiteText),
        headlineLarge: TextStyle(color: AppColors.offWhiteText),
        headlineMedium: TextStyle(color: AppColors.offWhiteText),
        headlineSmall: TextStyle(color: AppColors.offWhiteText),
        titleLarge: TextStyle(color: AppColors.offWhiteText),
        titleMedium: TextStyle(color: AppColors.offWhiteText),
        titleSmall: TextStyle(color: AppColors.offWhiteText),
        bodyLarge: TextStyle(color: AppColors.offWhiteText),
        bodyMedium: TextStyle(color: AppColors.offWhiteText),
        bodySmall: TextStyle(color: AppColors.offWhiteText),
        labelLarge: TextStyle(color: AppColors.offWhiteText),
        labelMedium: TextStyle(color: AppColors.offWhiteText),
        labelSmall: TextStyle(color: AppColors.offWhiteText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.creamBackground,
        foregroundColor: AppColors.charcoalCard,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.coralAccent,
        foregroundColor: AppColors.offWhiteText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coralAccent,
          foregroundColor: AppColors.offWhiteText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.coralAccent;
          }
          return AppColors.offWhiteText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.coralAccent.withValues(alpha: 0.5);
          }
          return AppColors.creamBackground.withValues(alpha: 0.5);
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.coralAccent,
        inactiveTrackColor: AppColors.creamBackground,
        thumbColor: AppColors.coralAccent,
      ),
    );
  }
}

enum ViewMode { grid, list }
enum SortOption { date, name, size }

class FileEngine {
  static Future<Directory> getApplicationDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<Directory> getPdfDirectory() async {
    final appDir = await getApplicationDirectory();
    final pdfDir = Directory('${appDir.path}/pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  static Future<List<FileSystemEntity>> searchLocalFiles(String query) async {
    try {
      final pdfDir = await getPdfDirectory();
      final files = pdfDir.listSync();
      
      if (query.isEmpty) {
        return files;
      }

      final lowerQuery = query.toLowerCase();
      return files.where((file) {
        final fileName = file.path.toLowerCase();
        return fileName.contains(lowerQuery);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      throw Exception('Failed to copy to clipboard: $e');
    }
  }

  static Future<void> movePdfFile(File sourceFile, Directory targetDirectory) async {
    try {
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }
      
      final fileName = sourceFile.path.split('/').last;
      final targetPath = '${targetDirectory.path}/$fileName';
      await sourceFile.rename(targetPath);
    } catch (e) {
      throw Exception('Failed to move file: $e');
    }
  }

  static Future<List<FileSystemEntity>> sortFiles(
    List<FileSystemEntity> files,
    SortOption sortOption,
  ) async {
    try {
      switch (sortOption) {
        case SortOption.date:
          files.sort((a, b) {
            final aStat = a.statSync();
            final bStat = b.statSync();
            return bStat.modified.compareTo(aStat.modified);
          });
          break;
        case SortOption.name:
          files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
          break;
        case SortOption.size:
          files.sort((a, b) {
            final aStat = a.statSync();
            final bStat = b.statSync();
            return bStat.size.compareTo(aStat.size);
          });
          break;
      }
      return files;
    } catch (e) {
      return files;
    }
  }

  static Future<void> shareFile(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  static Future<void> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  static Future<String> getFileName(File file) async {
    return file.path.split('/').last;
  }

  static Future<int> getFileSize(File file) async {
    try {
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  static Future<DateTime> getFileModifiedDate(File file) async {
    try {
      return await file.lastModified();
    } catch (e) {
      return DateTime.now();
    }
  }
}

class FullScreenManager {
  static bool _isFullScreen = false;

  static bool get isFullScreen => _isFullScreen;

  static Future<void> toggleFullScreen() async {
    try {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      _isFullScreen = false;
      throw Exception('Failed to toggle full screen: $e');
    }
  }

  static Future<void> exitFullScreen() async {
    try {
      if (_isFullScreen) {
        _isFullScreen = false;
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      throw Exception('Failed to exit full screen: $e');
    }
  }
}

class DashboardLayoutManager {
  static ViewMode _currentViewMode = ViewMode.grid;

  static ViewMode get currentViewMode => _currentViewMode;

  static void toggleViewMode() {
    _currentViewMode = _currentViewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
  }

  static void setViewMode(ViewMode mode) {
    _currentViewMode = mode;
  }
}
