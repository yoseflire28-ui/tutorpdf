import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'base_engine.dart';

class CsvEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const CsvEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<CsvEngine> createState() => _CsvEngineState();
}

class _CsvEngineState extends State<CsvEngine> {
  bool _isLoading = true;
  String? _error;
  List<List<dynamic>> _data = [];
  List<List<dynamic>> _filteredData = [];
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCsv();
  }

  @override
  void didUpdateWidget(CsvEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadCsv();
    }
  }

  Future<void> _loadCsv() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final content = await file.readAsString(encoding: utf8);

      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: true,
      ).convert(content);

      if (rows.isNotEmpty) {
        setState(() {
          _data = rows;
          _filteredData = rows;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'CSV file is empty.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to parse CSV document: $e';
        _isLoading = false;
      });
    }
  }

  void _filterData(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredData = _data);
      return;
    }

    final lower = query.toLowerCase();
    final header = _data.first;
    final body = _data.sublist(1).where((row) {
      return row.any((cell) => cell.toString().toLowerCase().contains(lower));
    }).toList();

    setState(() {
      _filteredData = [header, ...body];
    });
  }

  void _sortColumn(int colIdx) {
    if (_filteredData.length <= 1) return;

    final header = _filteredData.first;
    final body = List<List<dynamic>>.from(_filteredData.sublist(1));

    final isAsc = _sortColumnIndex == colIdx ? !_sortAscending : true;

    body.sort((a, b) {
      final valA = colIdx < a.length ? a[colIdx] : '';
      final valB = colIdx < b.length ? b[colIdx] : '';
      int cmp = 0;
      if (valA is Comparable && valB is Comparable) {
        cmp = valA.compareTo(valB);
      } else {
        cmp = valA.toString().compareTo(valB.toString());
      }
      return isAsc ? cmp : -cmp;
    });

    setState(() {
      _sortColumnIndex = colIdx;
      _sortAscending = isAsc;
      _filteredData = [header, ...body];
    });
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    if (_error != null || _data.isEmpty) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error ?? 'Unable to display CSV dataset.',
        isDarkMode: widget.isDarkMode,
        onRetry: _loadCsv,
      );
    }

    final maxCols = _data.fold<int>(0, (prev, row) => row.length > prev ? row.length : prev);

    return Container(
      color: canvasBg,
      child: Column(
        children: [
          // Filter & Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: headerBg,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterData,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search table rows...',
                      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: EngineColors.coralAccent, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      fillColor: cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_filteredData.length} rows',
                  style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // CSV Data Grid Table
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
                            return InkWell(
                              onTap: () => _sortColumn(colIdx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getColumnLetter(colIdx),
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    if (_sortColumnIndex == colIdx) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                        size: 14,
                                        color: EngineColors.coralAccent,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      // Data Rows
                      ...List.generate(_filteredData.length, (rowIdx) {
                        final row = _filteredData[rowIdx];
                        return TableRow(
                          decoration: BoxDecoration(
                            color: rowIdx == 0 ? headerBg.withValues(alpha: 0.5) : (rowIdx % 2 == 0 ? cardBg : cardBg.withValues(alpha: 0.85)),
                          ),
                          children: [
                            Container(
                              color: headerBg,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              alignment: Alignment.center,
                              child: Text(
                                '${rowIdx + 1}',
                                style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...List.generate(maxCols, (colIdx) {
                              final val = colIdx < row.length ? row[colIdx].toString() : '';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  val,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: rowIdx == 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
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
