import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/doc_to_html_engine.dart';

class RichDocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const RichDocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<RichDocumentViewerScreen> createState() => _RichDocumentViewerScreenState();
}

class _RichDocumentViewerScreenState extends State<RichDocumentViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  String? _htmlContent;
  int _currentPage = 1;
  int _pageCount = 1;
  String _documentTitle = 'Document';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF7F5EF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('Rich document webview error: ${error.description}');
          },
        ),
      );
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      final result = await DocToHtmlEngine().renderDocument(widget.filePath);
      if (!mounted) {
        return;
      }

      setState(() {
        _htmlContent = result.html;
        _pageCount = result.pageCount;
        _documentTitle = result.title;
        _isLoading = false;
      });

      await _controller.loadHtmlString(result.html);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to render document: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _documentTitle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _pageCount > 1 ? 'Slide $_currentPage / $_pageCount' : 'Preview',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else if (_htmlContent != null)
            WebViewWidget(controller: _controller)
          else
            const Center(child: Text('Preparing document…')),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.12),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
