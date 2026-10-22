import 'package:flutter/foundation.dart';
import '../../models/document.dart';
import '../../services/text_extraction_service.dart';

class ActiveDocumentProvider extends ChangeNotifier {
  final TextExtractionService _textExtractor = TextExtractionService();

  Document? _activeDocument;
  String? _extractedText;
  String? _convertedPdfPath;
  bool _isExtracting = false;

  Document? get activeDocument => _activeDocument;
  String? get extractedText => _extractedText;
  String? get convertedPdfPath => _convertedPdfPath;
  bool get hasActiveDocument => _activeDocument != null;
  bool get isExtracting => _isExtracting;

  Future<void> setActiveDocument(
    Document document, {
    String? extractedText,
    String? convertedPdfPath,
  }) async {
    _activeDocument = document;
    if (convertedPdfPath != null && convertedPdfPath.isNotEmpty) {
      _convertedPdfPath = convertedPdfPath;
    }

    if (extractedText != null && extractedText.isNotEmpty) {
      _extractedText = extractedText;
      _isExtracting = false;
      notifyListeners();
      return;
    }

    _isExtracting = true;
    notifyListeners();

    try {
      String text = '';
      if (document.filePath.isNotEmpty) {
        text = await _textExtractor.extractText(document.filePath);
      }
      if (text.isEmpty && _convertedPdfPath != null && _convertedPdfPath!.isNotEmpty) {
        text = await _textExtractor.extractText(_convertedPdfPath!);
      }
      _extractedText = text;
    } catch (e) {
      debugPrint('[ActiveDocumentProvider] Error extracting text: $e');
      _extractedText = '';
    } finally {
      _isExtracting = false;
      notifyListeners();
    }
  }

  void updateConvertedPdfPath(String path) {
    _convertedPdfPath = path;
    if (_activeDocument != null && (_extractedText == null || _extractedText!.isEmpty)) {
      _textExtractor.extractText(path).then((text) {
        if (text.isNotEmpty) {
          _extractedText = text;
          notifyListeners();
        }
      }).catchError((e) {
        debugPrint('[ActiveDocumentProvider] Error extracting text from converted PDF: $e');
      });
    } else {
      notifyListeners();
    }
  }

  void updateExtractedText(String text) {
    _extractedText = text;
    notifyListeners();
  }

  void clearActiveDocument() {
    _activeDocument = null;
    _extractedText = null;
    _convertedPdfPath = null;
    _isExtracting = false;
    notifyListeners();
  }
}
