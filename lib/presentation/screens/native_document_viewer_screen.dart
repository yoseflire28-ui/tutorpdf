import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/file_management_service.dart';

class NativeDocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const NativeDocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<NativeDocumentViewerScreen> createState() =>
      _NativeDocumentViewerScreenState();
}

class _NativeDocumentViewerScreenState extends State<NativeDocumentViewerScreen> {
  final FileManagementService _fileService = FileManagementService();
  bool _isPreparing = true;
  bool _isReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      await _fileService.ensureDocumentReadable(widget.filePath);
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _isReady = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _isReady = false;
        _errorMessage = e.toString().contains('permission')
            ? 'Unable to preview document natively. Please check file permissions or format.'
            : 'Unable to preview document natively. Please check file permissions or format.';
      });
    }
  }

  String _resolveViewerPath() {
    if (FileManagementService.isContentUri(widget.filePath)) {
      return widget.filePath;
    }

    final file = File(widget.filePath);
    if (file.existsSync()) {
      return widget.filePath;
    }

    return widget.filePath;
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.filePath.split('.').last.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              extension.isEmpty ? 'FILE' : extension,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              extension.isEmpty ? 'FILE' : extension,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isPreparing)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                ),
              )
            else if (_isReady)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 56, color: Colors.white70),
                      const SizedBox(height: 16),
                      Text(
                        'Document ready to open from ${widget.fileName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The native viewer package is unavailable in this build, so the app will keep the document in-app and present a safe fallback while preserving the original URI path.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.white70),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'Unable to preview document natively. Please check file permissions or format.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            if (_errorMessage != null && _isReady == false && _isPreparing == false)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D3D3F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
