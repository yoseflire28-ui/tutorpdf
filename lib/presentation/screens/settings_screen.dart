import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/settings_provider.dart';
import '../../core/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure settings are loaded
    final provider = context.read<SettingsProvider>();
    if (!provider.isInitialized) {
      provider.loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        if (!provider.isInitialized) {
          return Scaffold(
            backgroundColor: AppTheme.creamBackground,
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralAccent),
              ),
            ),
          );
        }

        final backgroundColor = provider.isDarkMode ? AppTheme.darkBackground : AppTheme.creamBackground;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text(
              'Settings Dashboard',
              style: TextStyle(
                color: AppTheme.offWhiteText,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppTheme.charcoalCard,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Appearance & Rendering', provider),
                const SizedBox(height: 12),
                _buildThemeCard(provider),
                const SizedBox(height: 12),
                _buildSwitchCard(
                  title: 'High-Definition Fonts',
                  subtitle: 'Optimize text anti-aliasing in reader',
                  icon: Icons.font_download_rounded,
                  value: provider.fontRefinement,
                  onChanged: (val) => provider.updateSettingParam('fontRefinement', val),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Hardware & Display', provider),
                const SizedBox(height: 12),
                _buildBrightnessCard(provider),
                const SizedBox(height: 12),
                _buildSwitchCard(
                  title: 'Keep Screen Awake',
                  subtitle: 'Force screen display to stay active',
                  icon: Icons.screen_lock_portrait_rounded,
                  value: provider.keepScreenOn,
                  onChanged: (val) => provider.updateSettingParam('keepScreenOn', val),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Localization & Viewport', provider),
                const SizedBox(height: 12),
                _buildLanguageCard(provider),
                const SizedBox(height: 12),
                _buildDefaultZoomCard(provider),
                const SizedBox(height: 24),
                _buildResetCard(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, SettingsProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: provider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
        ),
      ),
    );
  }

  Widget _buildThemeCard(SettingsProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.palette_rounded, color: AppTheme.offWhiteText),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: TextStyle(
                      color: AppTheme.offWhiteText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    provider.isDarkMode ? 'Dark Charcoal Theme' : 'Cream Light Theme',
                    style: TextStyle(
                      color: AppTheme.offWhiteText.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              provider.updateSettingParam('isDarkMode', !provider.isDarkMode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 60,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: provider.isDarkMode ? AppTheme.coralAccent : AppTheme.creamBackground.withValues(alpha: 0.3),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment: provider.isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.offWhiteText,
                  ),
                  child: Icon(
                    provider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 14,
                    color: provider.isDarkMode ? AppTheme.coralAccent : AppTheme.charcoalCard,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppTheme.offWhiteText),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.offWhiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.offWhiteText.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.offWhiteText,
          activeTrackColor: AppTheme.coralAccent,
          inactiveThumbColor: AppTheme.offWhiteText.withValues(alpha: 0.5),
          inactiveTrackColor: AppTheme.offWhiteText.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Widget _buildBrightnessCard(SettingsProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.brightness_medium_rounded, color: AppTheme.offWhiteText),
                  const SizedBox(width: 12),
                  Text(
                    'Screen Brightness',
                    style: const TextStyle(
                      color: AppTheme.offWhiteText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                provider.brightnessLevel < 0 
                    ? 'System' 
                    : '${(provider.brightnessLevel * 100).toInt()}%',
                style: const TextStyle(
                  color: AppTheme.coralAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.coralAccent,
              inactiveTrackColor: AppTheme.offWhiteText.withValues(alpha: 0.2),
              thumbColor: AppTheme.offWhiteText,
              overlayColor: AppTheme.coralAccent.withValues(alpha: 0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: provider.brightnessLevel < 0 ? 0.5 : provider.brightnessLevel,
              min: 0.0,
              max: 1.0,
              onChanged: (val) => provider.updateSettingParam('brightnessLevel', val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(SettingsProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded, color: AppTheme.offWhiteText),
              const SizedBox(width: 12),
              Text(
                'Application Language',
                style: const TextStyle(
                  color: AppTheme.offWhiteText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: provider.languageCode,
            dropdownColor: AppTheme.charcoalCard,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.creamBackground.withValues(alpha: 0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.coralAccent.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.coralAccent.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.coralAccent, width: 1.5),
              ),
            ),
            style: const TextStyle(color: AppTheme.offWhiteText, fontSize: 15),
            icon: Icon(Icons.arrow_drop_down_circle_rounded, color: AppTheme.coralAccent),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English (EN)')),
            ],
            onChanged: (val) {
              if (val != null) {
                provider.updateSettingParam('languageCode', val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultZoomCard(SettingsProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.zoom_in_rounded, color: AppTheme.offWhiteText),
              const SizedBox(width: 12),
              Text(
                'Default Viewport Zoom',
                style: const TextStyle(
                  color: AppTheme.offWhiteText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            initialValue: provider.defaultZoom,
            dropdownColor: AppTheme.charcoalCard,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.creamBackground.withValues(alpha: 0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.coralAccent.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.coralAccent.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.coralAccent, width: 1.5),
              ),
            ),
            style: const TextStyle(color: AppTheme.offWhiteText, fontSize: 15),
            icon: Icon(Icons.arrow_drop_down_circle_rounded, color: AppTheme.coralAccent),
            items: const [
              DropdownMenuItem(value: 1.0, child: Text('100% Zoom')),
              DropdownMenuItem(value: 1.5, child: Text('150% Zoom')),
              DropdownMenuItem(value: 2.0, child: Text('200% Zoom')),
            ],
            onChanged: (val) {
              if (val != null) {
                provider.updateSettingParam('defaultZoom', val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResetCard(SettingsProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.coralAccent,
          foregroundColor: AppTheme.offWhiteText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () {
          _showResetDialog(provider);
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_backup_restore_rounded),
            SizedBox(width: 8),
            Text(
              'Reset All Configurations',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.charcoalCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reset Configurations?',
            style: const TextStyle(color: AppTheme.offWhiteText, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to restore all configuration values back to system defaults?',
            style: TextStyle(color: AppTheme.offWhiteText.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.offWhiteText.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralAccent,
                foregroundColor: AppTheme.offWhiteText,
              ),
              onPressed: () {
                provider.resetToDefaults();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to defaults'),
                    backgroundColor: AppTheme.coralAccent,
                  ),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}

// Helper extension to make styling elevated button containers cleaner
extension on ElevatedButtonThemeData {
  Widget child(Widget child) => child;
}
