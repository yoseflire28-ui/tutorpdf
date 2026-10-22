import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../core/app_theme.dart';

/// Reader Menu Bar with File and View dropdown menus
/// Provides WPS-style document operations and view controls
class ReaderMenuBar extends StatelessWidget {
  final String filePath;
  final String fileExtension;
  final VoidCallback onRotationToggle;
  final VoidCallback onNightModeToggle;
  final VoidCallback onAIChat;
  final VoidCallback onExportToPDF;
  final VoidCallback onShare;
  final VoidCallback onPrint;
  final VoidCallback onFileInfo;

  const ReaderMenuBar({
    super.key,
    required this.filePath,
    required this.fileExtension,
    required this.onRotationToggle,
    required this.onNightModeToggle,
    required this.onAIChat,
    required this.onExportToPDF,
    required this.onShare,
    required this.onPrint,
    required this.onFileInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.charcoalCard,
      child: Row(
        children: [
          _buildMenuButton(
            context,
            'File',
            Icons.description,
            _buildFileMenu(context),
          ),
          _buildMenuButton(
            context,
            'View',
            Icons.visibility,
            _buildViewMenu(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String label,
    IconData icon,
    Widget menu,
  ) {
    return PopupMenuButton<String>(
      tooltip: label,
      color: AppTheme.charcoalCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) {
        // Handle menu selection
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: label,
          child: menu,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.offWhiteText, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppTheme.offWhiteText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMenu(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMenuItem(
          context,
          'Save As',
          Icons.save_as,
          () => _handleSaveAs(context),
        ),
        _buildMenuItem(
          context,
          'Export to PDF',
          Icons.picture_as_pdf,
          onExportToPDF,
        ),
        _buildMenuItem(
          context,
          'Share',
          Icons.share,
          onShare,
        ),
        _buildMenuItem(
          context,
          'Print',
          Icons.print,
          onPrint,
        ),
        const Divider(color: AppTheme.offWhiteText),
        _buildMenuItem(
          context,
          'File Info',
          Icons.info_outline,
          onFileInfo,
        ),
      ],
    );
  }

  Widget _buildViewMenu(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMenuItem(
          context,
          'Rotation',
          Icons.screen_rotation,
          onRotationToggle,
        ),
        _buildMenuItem(
          context,
          'Night Mode',
          Icons.dark_mode,
          onNightModeToggle,
        ),
        const Divider(color: AppTheme.offWhiteText),
        _buildMenuItem(
          context,
          'AI Chat',
          Icons.auto_awesome,
          onAIChat,
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.offWhiteText, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveAs(BuildContext context) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save As',
        fileName: path.basename(filePath),
        type: _getFilePickerType(fileExtension),
      );

      if (result != null) {
        final savedFile = File(result);
        await savedFile.writeAsBytes(bytes);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved to $result'),
              backgroundColor: AppTheme.coralAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  FileType _getFilePickerType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return FileType.custom;
      case 'docx':
        return FileType.custom;
      case 'pptx':
        return FileType.custom;
      case 'xlsx':
        return FileType.custom;
      case 'txt':
        return FileType.custom;
      case 'epub':
        return FileType.custom;
      default:
        return FileType.any;
    }
  }
}

/// File Info Modal Sheet
class FileInfoSheet extends StatelessWidget {
  final String filePath;
  final String fileExtension;
  final int pageCount;

  const FileInfoSheet({
    super.key,
    required this.filePath,
    required this.fileExtension,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final lastModified = file.existsSync() 
        ? file.lastModifiedSync() 
        : DateTime.now();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.offWhiteText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'File Information',
            style: TextStyle(
              color: AppTheme.offWhiteText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('File Name', fileName),
          _buildInfoRow('File Type', '.$fileExtension'.toUpperCase()),
          _buildInfoRow('File Path', filePath),
          _buildInfoRow('File Size', _formatFileSize(fileSize)),
          _buildInfoRow('Page Count', '$pageCount'),
          _buildInfoRow('Last Modified', _formatDate(lastModified)),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralAccent,
                  foregroundColor: AppTheme.offWhiteText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.offWhiteText.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
