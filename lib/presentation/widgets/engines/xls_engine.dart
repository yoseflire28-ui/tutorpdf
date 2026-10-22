import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'base_engine.dart';

class XlsEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const XlsEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<XlsEngine> createState() => _XlsEngineState();
}

class _XlsEngineState extends State<XlsEngine> {
  bool _isLoading = true;
  String? _error;
  List<List<String>> _matrix = [];

  @override
  void initState() {
    super.initState();
    _parseLegacyXls();
  }

  @override
  void didUpdateWidget(XlsEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseLegacyXls();
    }
  }

  Future<void> _parseLegacyXls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();

      // Legacy XLS binary parser: extract tab/newline or comma delimited printable records
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = content.split(RegExp(r'\r\n|\r|\n'));

      final List<List<String>> rows = [];
      for (final line in lines) {
        final clean = line.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '').trim();
        if (clean.isNotEmpty) {
          final cells = clean.split(RegExp(r'\t|,'));
          if (cells.any((c) => c.trim().isNotEmpty)) {
            rows.add(cells);
          }
        }
      }

      if (rows.isNotEmpty) {
        setState(() {
          _matrix = rows;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Legacy XLS binary format could not be parsed into a cell matrix.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load XLS document: $e';
        _isLoading = false;
      });
    }
  }

  String _getColumnLetter(int index) {
    String letter = '';
    while (index >= 0) {
      letter = String.fromCharCode((index % 26) + 65) + letter;
      index = (index ~/ 26) - 1;
    }
    return letter;
  }

  @override
  Widget build(BuildContext context) {
    final canvasBg = widget.isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas;
    final cardBg = widget.isDarkMode ? EngineColors.darkCard : EngineColors.lightCard;
    final textColor = widget.isDarkMode ? EngineColors.darkText : EngineColors.lightText;
    final borderColor = textColor.withValues(alpha: 0.2);
    final headerBg = widget.isDarkMode ? const Color(0xFF2D2D30) : const Color(0xFFE8E8E8);

    if (_isLoading) {
      return Container(
        color: canvasBg,
        child: const Center(
          child: CircularProgressIndicator(color: EngineColors.coralAccent),
        ),
      );
    }

    if (_error != null || _matrix.isEmpty) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error ?? 'No cell data available.',
        isDarkMode: widget.isDarkMode,
        onRetry: _parseLegacyXls,
      );
    }

    final maxCols = _matrix.fold<int>(0, (prev, row) => row.length > prev ? row.length : prev);

    return Container(
      color: canvasBg,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: borderColor, width: 1),
              children: [
                // Header Row
                TableRow(
                  decoration: BoxDecoration(color: headerBg),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      alignment: Alignment.center,
                      child: Text('#', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    ...List.generate(maxCols, (colIdx) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        alignment: Alignment.center,
                        child: Text(
                          _getColumnLetter(colIdx),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      );
                    }),
                  ],
                ),
                // Matrix Rows
                ...List.generate(_matrix.length, (rowIdx) {
                  final row = _matrix[rowIdx];
                  return TableRow(
                    decoration: BoxDecoration(color: rowIdx % 2 == 0 ? cardBg : cardBg.withValues(alpha: 0.85)),
                    children: [
                      Container(
                        color: headerBg,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        alignment: Alignment.center,
                        child: Text('${rowIdx + 1}', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      ...List.generate(maxCols, (colIdx) {
                        final val = colIdx < row.length ? row[colIdx] : '';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(val, style: TextStyle(color: textColor, fontSize: 13)),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
