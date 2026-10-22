import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'base_engine.dart';

class TxtEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const TxtEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<TxtEngine> createState() => _TxtEngineState();
}

class _TxtEngineState extends State<TxtEngine> {
  bool _isLoading = true;
  String? _error;
  List<String> _lines = [];
  bool _isMonospace = true;
  bool _showLineNumbers = true;

  @override
  void initState() {
    super.initState();
    _loadTxt();
  }

  @override
  void didUpdateWidget(TxtEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadTxt();
    }
  }

  Future<void> _loadTxt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final content = await file.readAsString(encoding: utf8);
      final lines = content.split(RegExp(r'\r\n|\r|\n'));

      setState(() {
        _lines = lines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load text document: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasBg = widget.isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas;
    final cardBg = widget.isDarkMode ? EngineColors.darkCard : EngineColors.lightCard;
    final textColor = widget.isDarkMode ? EngineColors.darkText : EngineColors.lightText;
    final lineNumberColor = textColor.withValues(alpha: 0.4);

    if (_isLoading) {
      return Container(
        color: canvasBg,
        child: const Center(
          child: CircularProgressIndicator(color: EngineColors.coralAccent),
        ),
      );
    }

    if (_error != null) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error!,
        isDarkMode: widget.isDarkMode,
        onRetry: _loadTxt,
      );
    }

    return Container(
      color: canvasBg,
      child: Column(
        children: [
          // Plain Text View Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: widget.isDarkMode ? const Color(0xFF252526) : const Color(0xFFD6D6D6),
            child: Row(
              children: [
                Text(
                  'Lines: ${_lines.length}',
                  style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('Line Numbers', style: TextStyle(color: textColor, fontSize: 12)),
                Switch(
                  value: _showLineNumbers,
                  activeTrackColor: EngineColors.coralAccent,
                  onChanged: (val) => setState(() => _showLineNumbers = val),
                ),
                const SizedBox(width: 8),
                Text('Monospace', style: TextStyle(color: textColor, fontSize: 12)),
                Switch(
                  value: _isMonospace,
                  activeTrackColor: EngineColors.coralAccent,
                  onChanged: (val) => setState(() => _isMonospace = val),
                ),
              ],
            ),
          ),
          // Text Sheet Container - Full Width
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                color: cardBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lines.length,
                  itemBuilder: (context, idx) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_showLineNumbers) ...[
                            SizedBox(
                              width: 45,
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  color: lineNumberColor,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: SelectableText(
                              _lines[idx].isEmpty ? ' ' : _lines[idx],
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontFamily: _isMonospace ? 'monospace' : 'Roboto',
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
