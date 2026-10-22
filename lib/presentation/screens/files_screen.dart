import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/providers/document_provider.dart';
import '../../data/providers/settings_provider.dart';
import '../../models/document.dart';
import '../../utils/file_icon_helper.dart';
import '../../utils/document_navigation.dart';
import 'package:provider/provider.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  @override
  void initState() {
    super.initState();
    // Load documents from provider on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadDocuments();
    });
  }

  Future<void> _importFile() async {
    final doc = await context.read<DocumentProvider>().importDocument();
    if (doc != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported: ${doc.fileName}'),
          backgroundColor: AppTheme.coralAccent,
        ),
      );
    }
  }

  void _openDocument(Document doc) {
    DocumentNavigation.openDocument(context, doc);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DocumentProvider, SettingsProvider>(
      builder: (context, documentProvider, settingsProvider, child) {
        final backgroundColor = settingsProvider.isDarkMode 
            ? AppTheme.darkBackground 
            : AppTheme.creamBackground;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text(
              'Document Library',
              style: TextStyle(
                color: AppTheme.offWhiteText,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppTheme.charcoalCard,
            elevation: 0,
            centerTitle: true,
          ),
          body: documentProvider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralAccent),
                  ),
                )
              : !documentProvider.hasDocuments
                  ? _buildEmptyState()
                  : _buildFileList(documentProvider.documents),
          floatingActionButton: FloatingActionButton(
            onPressed: _importFile,
            backgroundColor: AppTheme.coralAccent,
            foregroundColor: AppTheme.offWhiteText,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 80,
                  color: settings.isDarkMode ? AppTheme.offWhiteText.withValues(alpha: 0.5) : AppTheme.charcoalCard,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Documents Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: settings.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to import a PDF, TXT, or EPUB document.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: settings.isDarkMode ? AppTheme.offWhiteText.withValues(alpha: 0.7) : AppTheme.charcoalCard,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileList(List<Document> documents) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.charcoalCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: FileIconHelper.getColor(doc.fileType),
              child: Icon(
                FileIconHelper.getIcon(doc.fileType),
                color: AppTheme.offWhiteText,
              ),
            ),
            title: Text(
              doc.fileName,
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Last opened: ${_formatDate(doc.lastOpened)}',
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.offWhiteText,
              size: 16,
            ),
            onTap: () => _openDocument(doc),
          ),
        );
      },
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
