import 'package:flutter/material.dart';
import '../utils/document_router.dart';
import '../models/document.dart';
import '../services/file_management_service.dart';
import 'document_viewer_screen.dart';
import 'analytics_screen.dart';
import 'api_settings_screen.dart';
import 'ai_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _fileService = FileManagementService();
  List<Document> _documents = [];
  List<Document> _filteredDocuments = [];
  bool _isLoadingList = false;
  bool _isImporting = false;
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDocuments(showLoader: true);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    try {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _filteredDocuments = _documents;
        } else {
          _filteredDocuments = _documents.where((doc) {
            return doc.fileName.toLowerCase().contains(query);
          }).toList();
        }
      });
      debugPrint('Search query: "$query", filtered results: ${_filteredDocuments.length}');
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  Future<void> _loadDocuments({bool showLoader = false}) async {
    if (showLoader) setState(() => _isLoadingList = true);
    try {
      final docs = await _fileService.fetchAllOrderedByLastOpened();
      if (mounted) {
        setState(() {
          _documents = docs;
          _filteredDocuments = docs;
          _isLoadingList = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load documents: $e');
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _importDocument() async {
    if (_isImporting) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening file picker…'),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _isImporting = true);
    try {
      // Open the picker before any heavy work; keep the UI responsive.
      final doc = await _fileService.pickAndImportDocument();
      if (!mounted) return;
      if (doc != null) {
        await _loadDocuments();
        if (mounted) _openDocument(doc);
      }
    } catch (e, st) {
      debugPrint('Import failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openDocument(Document doc) async {
    try {
      debugPrint('Opening document: ${doc.fileName} (${doc.category})');
      openDocumentFromModel(context, doc);
      if (doc.id.isNotEmpty) {
        await _fileService.updateCurrentPage(doc.id, doc.currentPage);
      }
      _loadDocuments();
    } catch (e) {
      debugPrint('Error opening document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open document: $e'),
            backgroundColor: const Color(0xFFE65A4B),
          ),
        );
      }
    }
  }

  Future<void> _openWithExternalViewer(Document doc) async {
    openDocumentFromModel(context, doc);
  }

  Future<void> _deleteDocument(Document doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text(
            'Delete "${doc.fileName}"? All bookmarks, notes, and chat history will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _fileService.deleteDocument(doc.id);
      _loadDocuments();
    }
  }

  Future<void> _toggleFavorite(Document doc) async {
    await _fileService.toggleFavorite(doc.id, !doc.isFavorite);
    _loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'TutorPDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isImporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                : const Icon(Icons.upload_file_rounded, color: Colors.white70),
            tooltip: 'Import document',
            onPressed: _isImporting ? null : _importDocument,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70),
            tooltip: 'Analytics',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApiSettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'search documents...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF0F1117),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6C63FF),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: const [
                  Tab(text: 'All Files'),
                  Tab(text: 'Favorites'),
                  Tab(icon: Icon(Icons.history_rounded, size: 18)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DocumentList(
            documents: _filteredDocuments,
            onOpen: _openDocument,
            onDelete: _deleteDocument,
            onFavorite: _toggleFavorite,
            emptyMessage: _searchQuery.isNotEmpty 
                ? 'No documents match "$_searchQuery".'
                : 'No documents yet.\nTap Import to add a PDF or text file.',
            isLoading: _isLoadingList && _filteredDocuments.isEmpty,
          ),
          _DocumentList(
            documents: _filteredDocuments.where((d) => d.isFavorite).toList(),
            onOpen: _openDocument,
            onDelete: _deleteDocument,
            onFavorite: _toggleFavorite,
            emptyMessage: _searchQuery.isNotEmpty 
                ? 'No favorites match "$_searchQuery".'
                : 'No favorites yet.\nStar a document to pin it here.',
            isLoading: false,
          ),
          _DocumentList(
            documents: _filteredDocuments.take(10).toList(),
            onOpen: _openDocument,
            onDelete: _deleteDocument,
            onFavorite: _toggleFavorite,
            emptyMessage: _searchQuery.isNotEmpty 
                ? 'No recent files match "$_searchQuery".'
                : 'No recent files.',
            isLoading: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImporting ? null : _importDocument,
        backgroundColor: const Color(0xFF6C63FF),
        icon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _isImporting ? 'Importing…' : 'Import',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  final List<Document> documents;
  final void Function(Document) onOpen;
  final void Function(Document) onDelete;
  final void Function(Document) onFavorite;
  final String emptyMessage;
  final bool isLoading;

  const _DocumentList({
    required this.documents,
    required this.onOpen,
    required this.onDelete,
    required this.onFavorite,
    required this.emptyMessage,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }
    if (documents.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 15, height: 1.6),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: documents.length,
      itemBuilder: (_, i) => _DocumentCard(
        document: documents[i],
        onOpen: onOpen,
        onDelete: onDelete,
        onFavorite: onFavorite,
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Document document;
  final void Function(Document) onOpen;
  final void Function(Document) onDelete;
  final void Function(Document) onFavorite;

  const _DocumentCard({
    required this.document,
    required this.onOpen,
    required this.onDelete,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          try {
            debugPrint('Opening document: ${document.fileName} (ID: ${document.id})');
            onOpen(document);
          } catch (e) {
            debugPrint('Error opening document: $e');
          }
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
        highlightColor: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  document.icon,
                  color: const Color(0xFF6C63FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          document.category,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (document.totalPages > 0)
                          Text(
                            '• ${document.totalPages} pages',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        if (document.requiresExternalViewer)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.open_in_new,
                              color: Colors.white38,
                              size: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF6C63FF),
                ),
                tooltip: 'AI Chat',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiChatScreen(
                        document: document,
                        currentPage: document.currentPage,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  document.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: document.isFavorite
                      ? const Color(0xFFFFD700)
                      : Colors.white38,
                ),
                onPressed: () => onFavorite(document),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                onPressed: () => onDelete(document),
              ),
            ],
          ),
        ),
      ),
    );
  }
}