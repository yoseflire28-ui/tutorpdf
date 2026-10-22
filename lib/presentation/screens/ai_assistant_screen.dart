import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/document_provider.dart';
import '../../data/providers/active_document_provider.dart';
import '../../models/document.dart';
import '../../screens/ai_chat_screen.dart';
import '../../utils/file_icon_helper.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final docProvider = context.read<DocumentProvider>();
      final activeProvider = context.read<ActiveDocumentProvider>();

      docProvider.loadDocuments().then((_) {
        if (!activeProvider.hasActiveDocument && docProvider.documents.isNotEmpty) {
          final supportedDocs = docProvider.documents
              .where((d) => FileIconHelper.isAiSupportedFile(d.fileType))
              .toList();
          if (supportedDocs.isNotEmpty) {
            activeProvider.setActiveDocument(supportedDocs.first);
          }
        }
      });
    });
  }

  void _startChat(Document doc) {
    context.read<ActiveDocumentProvider>().setActiveDocument(doc);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiChatScreen(
          document: doc,
        ),
      ),
    );
  }

  Future<void> _handleImportDocument() async {
    final docProvider = context.read<DocumentProvider>();
    final activeProvider = context.read<ActiveDocumentProvider>();

    final importedDoc = await docProvider.importDocument();
    if (importedDoc != null && mounted) {
      await activeProvider.setActiveDocument(importedDoc);
      _startChat(importedDoc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DocumentProvider, ActiveDocumentProvider>(
      builder: (context, documentProvider, activeDocumentProvider, child) {
        final allSupportedDocuments = documentProvider.documents
            .where((d) => FileIconHelper.isAiSupportedFile(d.fileType))
            .toList();

        final hasActiveDoc = activeDocumentProvider.hasActiveDocument;
        final activeDoc = activeDocumentProvider.activeDocument;

        return Scaffold(
          backgroundColor: const Color(0xFFEFE7DC),
          appBar: AppBar(
            title: const Text(
              'AI Study Assistant',
              style: TextStyle(
                color: Color(0xFFF9F6F0),
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF3D3D3F),
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFF9F6F0)),
                tooltip: 'Import Document',
                onPressed: _handleImportDocument,
              ),
            ],
          ),
          body: documentProvider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE65A4B)),
                  ),
                )
              : (!hasActiveDoc && allSupportedDocuments.isEmpty)
                  ? _buildEmptyState()
                  : _buildActiveAndDocumentList(
                      activeDoc: activeDoc ?? (allSupportedDocuments.isNotEmpty ? allSupportedDocuments.first : null),
                      allDocuments: allSupportedDocuments,
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.psychology_rounded,
              size: 80,
              color: Color(0xFF3D3D3F),
            ),
            const SizedBox(height: 16),
            const Text(
              'Import a Document to Start AI Study',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3D3D3F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The AI Assistant supports PDF, DOCX, PPTX, and text documents to analyze content and answer study questions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF3D3D3F),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleImportDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65A4B),
                foregroundColor: const Color(0xFFF9F6F0),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text(
                'Import Document (PDF, DOCX, PPTX)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAndDocumentList({
    required Document? activeDoc,
    required List<Document> allDocuments,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (activeDoc != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3D3D3F),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFE65A4B), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'ACTIVE STUDY DOCUMENT',
                      style: TextStyle(
                        color: Color(0xFFE65A4B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: FileIconHelper.getColor(activeDoc.fileType),
                      child: Icon(
                        FileIconHelper.getIcon(activeDoc.fileType),
                        color: const Color(0xFFF9F6F0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeDoc.fileName,
                            style: const TextStyle(
                              color: Color(0xFFF9F6F0),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Format: ${activeDoc.fileType.toUpperCase()}',
                            style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startChat(activeDoc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65A4B),
                      foregroundColor: const Color(0xFFF9F6F0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text(
                      'Start AI Chat & Study',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'All Imported Study Documents',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D3D3F),
          ),
        ),
        const SizedBox(height: 12),
        if (allDocuments.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No other documents imported yet.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          )
        else
          ...allDocuments.map((doc) {
            final isSelected = activeDoc?.id == doc.id || activeDoc?.filePath == doc.filePath;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3D3D3F) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: isSelected
                    ? Border.all(color: const Color(0xFFE65A4B), width: 1.5)
                    : Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: FileIconHelper.getColor(doc.fileType),
                  child: Icon(
                    FileIconHelper.getIcon(doc.fileType),
                    color: const Color(0xFFF9F6F0),
                  ),
                ),
                title: Text(
                  doc.fileName,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFF9F6F0) : const Color(0xFF111827),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Format: ${doc.fileType.toUpperCase()}',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isSelected ? const Color(0xFFE65A4B) : const Color(0xFF9CA3AF),
                  size: 16,
                ),
                onTap: () => _startChat(doc),
              ),
            );
          }),
      ],
    );
  }
}
