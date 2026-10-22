import 'package:flutter/foundation.dart';
import '../../models/document.dart';
import '../../services/file_management_service.dart';

class DocumentProvider extends ChangeNotifier {
  final FileManagementService _fileService = FileManagementService();
  
  List<Document> _documents = [];
  bool _isLoading = false;
  String? _error;

  List<Document> get documents => _documents;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasDocuments => _documents.isNotEmpty;
  int get documentCount => _documents.length;

  DocumentProvider() {
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final docs = await _fileService.fetchAllOrderedByLastOpened();
      _documents = docs;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('Error loading documents: $e');
      notifyListeners();
    }
  }

  Future<Document?> importDocument() async {
    try {
      final doc = await _fileService.pickAndImportDocument();
      if (doc != null) {
        await loadDocuments();
        return doc;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error importing document: $e');
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteDocument(dynamic documentId) async {
    try {
      await _fileService.deleteDocument(documentId);
      await loadDocuments();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting document: $e');
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(dynamic documentId, bool isFavorite) async {
    try {
      await _fileService.toggleFavorite(documentId, isFavorite);
      await loadDocuments();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error toggling favorite: $e');
      notifyListeners();
    }
  }

  List<Document> getRecentDocuments({int limit = 10}) {
    return _documents.take(limit).toList();
  }

  List<Document> searchDocuments(String query) {
    if (query.isEmpty) return _documents;
    final lowerQuery = query.toLowerCase();
    return _documents.where((doc) =>
      doc.fileName.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
