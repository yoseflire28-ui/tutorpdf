import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'base_engine.dart';

class OdsEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const OdsEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<OdsEngine> createState() => _OdsEngineState();
}

class _OdsEngineState extends State<OdsEngine> {
  bool _isLoading = true;
  String? _error;
  List<OdsSheet> _sheets = [];
  int _activeSheetIndex = 0;

  @override
  void initState() {
    super.initState();
    _parseOds();
  }

  @override
  void didUpdateWidget(OdsEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseOds();
    }
  }

  Future<void> _parseOds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final contentFile = archive.findFile('content.xml');

      if (contentFile == null) {
        setState(() {
          _error = 'content.xml missing from ODS package.';
          _isLoading = false;
        });
        return;
      }

      final contentStr = utf8.decode(contentFile.content as List<int>, allowMalformed: true);
      final doc = xml.XmlDocument.parse(contentStr);

      final List<OdsSheet> sheets = [];
      final tableNodes = doc.findAllElements('table:table');

      for (final tblNode in tableNodes) {
        final sheetName = tblNode.getAttribute('table:name') ?? 'Sheet ${sheets.length + 1}';
        final List<List<String>> rows = [];

        for (final tr in tblNode.findAllElements('table:table-row')) {
          final row = <String>[];
          for (final tc in tr.findAllElements('table:table-cell')) {
            row.add(tc.innerText.trim());
          }
          if (row.any((cell) => cell.isNotEmpty)) {
            rows.add(row);
          }
        }

        if (rows.isNotEmpty) {
          sheets.add(OdsSheet(name: sheetName, matrix: rows));
        }
      }

      if (sheets.isNotEmpty) {
        setState(() {
          _sheets = sheets;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No spreadsheet tables found in ODS document.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to parse ODS spreadsheet: $e';
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

    if (_error != null || _sheets.isEmpty) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error ?? 'Unable to display ODS file.',
        isDarkMode: widget.isDarkMode,
        onRetry: _parseOds,
      );
    }

    final activeSheet = _sheets[_activeSheetIndex];
    final maxCols = activeSheet.matrix.fold<int>(0, (prev, row) => row.length > prev ? row.length : prev);

    return Container(
      color: canvasBg,
      child: Column(
        children: [
          // Sheet Tabs
          Container(
            height: 44,
            color: headerBg,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sheets.length,
              itemBuilder: (context, idx) {
                final isSel = idx == _activeSheetIndex;
                return GestureDetector(
                  onTap: () => setState(() => _activeSheetIndex = idx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel ? cardBg : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: isSel ? EngineColors.coralAccent : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      _sheets[idx].name,
                      style: TextStyle(
                        color: isSel ? EngineColors.coralAccent : textColor,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Spreadsheet Grid
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(color: borderColor, width: 1),
                    children: [
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
                      ...List.generate(activeSheet.matrix.length, (rowIdx) {
                        final row = activeSheet.matrix[rowIdx];
                        return TableRow(
                          decoration: BoxDecoration(
                            color: rowIdx % 2 == 0 ? cardBg : cardBg.withValues(alpha: 0.85),
                          ),
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
          ),
        ],
      ),
    );
  }
}

class OdsSheet {
  final String name;
  final List<List<String>> matrix;
  OdsSheet({required this.name, required this.matrix});
}
