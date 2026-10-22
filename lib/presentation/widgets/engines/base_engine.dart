import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class EngineColors {
  // Dark Mode Theme
  static const Color darkCanvas = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF3D3D3F);
  static const Color darkText = Color(0xFFF5F5F5);

  // Light Mode Theme
  static const Color lightCanvas = Color(0xFFE0E0E0);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1A1A1A);

  // Accent & Highlights
  static const Color coralAccent = Color(0xFFE65A4B);
}

/// Fallback error boundary card displayed when an engine encounters a file reading/parsing error
class EngineErrorBoundary extends StatelessWidget {
  final String filePath;
  final String errorMessage;
  final bool isDarkMode;
  final VoidCallback? onRetry;

  const EngineErrorBoundary({
    super.key,
    required this.filePath,
    required this.errorMessage,
    required this.isDarkMode,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final canvasBg = isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas;
    final cardBg = isDarkMode ? EngineColors.darkCard : EngineColors.lightCard;
    final textColor = isDarkMode ? EngineColors.darkText : EngineColors.lightText;

    return Container(
      color: canvasBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24.0),
      child: Card(
        color: cardBg,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: EngineColors.coralAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EngineColors.coralAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: EngineColors.coralAccent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Engine Rendering Error',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onRetry != null) ...[
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, color: EngineColors.coralAccent),
                      label: const Text('Retry', style: TextStyle(color: EngineColors.coralAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: EngineColors.coralAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: () {
                      OpenFilex.open(filePath);
                    },
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    label: const Text('Open with System App', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EngineColors.coralAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
