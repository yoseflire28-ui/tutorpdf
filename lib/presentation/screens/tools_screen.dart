import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/providers/settings_provider.dart';
import '../../screens/study_screen.dart';
import '../../screens/analytics_screen.dart';
import 'package:provider/provider.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final backgroundColor = settings.isDarkMode 
            ? AppTheme.darkBackground 
            : AppTheme.creamBackground;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text(
              'Learning Utilities',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Text(
                    'Available Toolkits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: settings.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildToolCard(
                  context: context,
                  icon: Icons.assignment_rounded,
                  title: 'AI Study Planner',
                  description: 'Manage study materials, configure topics, and track target learning goals.',
                  onTap: () => _navigateTo(context, const StudyScreen()),
                ),
                const SizedBox(height: 16),
                _buildToolCard(
                  context: context,
                  icon: Icons.bar_chart_rounded,
                  title: 'Learning Analytics',
                  description: 'Visualize your reading stats, daily study charts, and progress overview.',
                  onTap: () => _navigateTo(context, const AnalyticsScreen()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: AppTheme.coralAccent.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.coralAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: AppTheme.offWhiteText,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.offWhiteText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.offWhiteText.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppTheme.offWhiteText,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
