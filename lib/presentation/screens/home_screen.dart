import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/document.dart';
import '../../screens/ai_chat_screen.dart';
import '../../screens/study_screen.dart';
import '../../screens/summary_screen.dart';
import '../../data/providers/document_provider.dart';
import '../../data/providers/settings_provider.dart';
import '../../utils/file_icon_helper.dart';
import '../../utils/document_navigation.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Document> _filteredDocuments = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Load documents from provider on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadDocuments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    final provider = context.read<DocumentProvider>();
    setState(() {
      _filteredDocuments = provider.searchDocuments(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DocumentProvider, SettingsProvider>(
      builder: (context, documentProvider, settingsProvider, child) {
        // Initialize filtered documents if empty
        if (_filteredDocuments.isEmpty && _searchController.text.isEmpty) {
          _filteredDocuments = documentProvider.getRecentDocuments(limit: 3);
        }

        final backgroundColor = settingsProvider.isDarkMode 
            ? AppTheme.darkBackground 
            : AppTheme.creamBackground;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSearchBar(),
                      const SizedBox(height: 24),
                      _buildDashboardGrid(documentProvider),
                      const SizedBox(height: 24),
                      _buildRecentFilesSection(documentProvider, settingsProvider),
                      const SizedBox(height: 24),
                      _buildLearningStatistics(documentProvider, settingsProvider),
                      const SizedBox(height: 24),
                      _buildStudyGoalsBanner(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3D3D3F),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: const Text(
        'Tutorpdf',
        style: TextStyle(
          color: AppTheme.offWhiteText,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: AppTheme.offWhiteText.withValues(alpha: 0.6),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: AppTheme.offWhiteText,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: TextStyle(
                    color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.clear,
                  color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: () {
                  _searchController.clear();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(DocumentProvider documentProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          _buildDashboardCard(
            icon: Icons.chat_bubble_outline,
            title: 'AI Chat',
            subtitle: 'Ask questions',
            onTap: () => _handleAIChat(documentProvider),
          ),
          _buildDashboardCard(
            icon: Icons.quiz_outlined,
            title: 'Quizzes',
            subtitle: 'Test knowledge',
            onTap: () => _handleStudyFeature('quiz', documentProvider),
          ),
          _buildDashboardCard(
            icon: Icons.style_outlined,
            title: 'Flashcards',
            subtitle: 'Quick review',
            onTap: () => _handleStudyFeature('flashcard', documentProvider),
          ),
          _buildDashboardCard(
            icon: Icons.summarize_outlined,
            title: 'Summary',
            subtitle: 'Key points',
            onTap: () => _handleStudyFeature('summary', documentProvider),
          ),
        ],
      ),
    );
  }

  void _handleAIChat(DocumentProvider documentProvider) {
    if (!documentProvider.hasDocuments) {
      _showNoDocumentSnackBar();
      return;
    }
    // AI chat works in guest (local) mode — no sign-in required.
    _proceedToAIChat(documentProvider);
  }

  void _proceedToAIChat(DocumentProvider documentProvider) {
    if (documentProvider.documents.length == 1) {
      _navigateToAIChat(documentProvider.documents.first);
    } else {
      _showDocumentSelectionDialog(documentProvider.documents, (selectedDoc) {
        _navigateToAIChat(selectedDoc);
      });
    }
  }

  void _navigateToAIChat(Document document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiChatScreen(
          document: document,
          currentPage: document.currentPage,
        ),
      ),
    );
  }

  void _handleStudyFeature(String feature, DocumentProvider documentProvider) {
    if (!documentProvider.hasDocuments) {
      _showNoDocumentSnackBar();
      return;
    }
    
    if (documentProvider.documents.length == 1) {
      if (feature == 'summary') {
        _navigateToSummaryScreen(documentProvider.documents.first);
      } else {
        _navigateToStudyScreen(documentProvider.documents.first, feature);
      }
    } else {
      _showDocumentSelectionDialog(documentProvider.documents, (selectedDoc) {
        if (feature == 'summary') {
          _navigateToSummaryScreen(selectedDoc);
        } else {
          _navigateToStudyScreen(selectedDoc, feature);
        }
      });
    }
  }

  void _navigateToStudyScreen(Document document, String feature) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyScreen(
          document: document,
          currentPage: document.currentPage,
        ),
      ),
    );
  }

  void _navigateToSummaryScreen(Document document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          document: document,
          currentPage: document.currentPage,
        ),
      ),
    );
  }

  void _showNoDocumentSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please import a document first',
          style: TextStyle(color: AppTheme.offWhiteText),
        ),
        backgroundColor: AppTheme.charcoalCard,
      ),
    );
  }

  void _showDocumentSelectionDialog(List<Document> documents, Function(Document) onDocumentSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.charcoalCard,
        title: const Text(
          'Select a Document',
          style: TextStyle(color: AppTheme.offWhiteText),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return ListTile(
                title: Text(
                  doc.fileName,
                  style: const TextStyle(color: AppTheme.offWhiteText),
                ),
                subtitle: Text(
                  '${doc.fileType.toUpperCase()} • ${doc.totalPages} pages',
                  style: TextStyle(color: AppTheme.offWhiteText.withValues(alpha: 0.6)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDocumentSelected(doc);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.charcoalCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.coralAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.coralAccent,
                  size: 28,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.offWhiteText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                      fontSize: 14,
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

  Widget _buildRecentFilesSection(DocumentProvider documentProvider, SettingsProvider settingsProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Files',
                style: TextStyle(
                  color: settingsProvider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to all files
                },
                child: const Text(
                  'See All',
                  style: TextStyle(
                    color: AppTheme.coralAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (documentProvider.isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.coralAccent,
              ),
            )
          else if (!documentProvider.hasDocuments)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'No documents yet',
                  style: TextStyle(
                    color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            Column(
              children: _filteredDocuments.take(3).map((doc) => _buildDocumentCard(doc)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Document document) {
    return InkWell(
      onTap: () {
        DocumentNavigation.openDocument(context, document);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FileIconHelper.getColor(document.fileType).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                FileIconHelper.getIcon(document.fileType),
                color: FileIconHelper.getColor(document.fileType),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.fileName,
                    style: const TextStyle(
                      color: AppTheme.offWhiteText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${FileIconHelper.getCategory(document.fileType)} • ${document.fileType.toUpperCase()}',
                    style: TextStyle(
                      color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.offWhiteText.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningStatistics(DocumentProvider documentProvider, SettingsProvider settingsProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Statistics',
            style: TextStyle(
              color: settingsProvider.isDarkMode ? AppTheme.offWhiteText : AppTheme.charcoalCard,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.book_outlined,
                  label: 'Docs',
                  value: documentProvider.documentCount.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up_outlined,
                  label: 'Progress',
                  value: '75%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.help_outline,
                  label: 'Queries',
                  value: '24',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.coralAccent,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.offWhiteText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.offWhiteText.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyGoalsBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Study Goals',
                  style: TextStyle(
                    color: AppTheme.offWhiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.coralAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '3/5',
                    style: TextStyle(
                      color: AppTheme.offWhiteText,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: 0.6,
                backgroundColor: AppTheme.offWhiteText.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.coralAccent),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Keep going! You\'re making great progress.',
              style: TextStyle(
                color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
