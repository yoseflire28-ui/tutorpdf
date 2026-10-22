import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import '../universal_document_controller.dart';

class XlsxGridEngine extends StatefulWidget {
  final UniversalDocumentController controller;

  const XlsxGridEngine({
    super.key,
    required this.controller,
  });

  @override
  State<XlsxGridEngine> createState() => _XlsxGridEngineState();
}

class _XlsxGridEngineState extends State<XlsxGridEngine> with SingleTickerProviderStateMixin {
  xl.Excel? _excel;
  late TabController _tabController;
  bool _isParsing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parseExcel();
  }

  Future<void> _parseExcel() async {
    try {
      if (widget.controller.fileBytes == null) {
        throw Exception("No file bytes available for Excel parsing.");
      }

      // 3. NATIVE FORMAT PARSERS: XLSX
      _excel = xl.Excel.decodeBytes(widget.controller.fileBytes!);
      
      _tabController = TabController(
        length: _excel!.tables.keys.length,
        vsync: this,
      );

      // 17. DECOUPLED SEARCH & AI ENGINE: Extract text for AI
      final plainTextBuffer = StringBuffer();
      for (var table in _excel!.tables.keys) {
        plainTextBuffer.writeln("Sheet: $table");
        final sheet = _excel!.tables[table]!;
        for (var row in sheet.rows) {
          plainTextBuffer.writeln(row.map((cell) => cell?.value?.toString() ?? "").join(" | "));
        }
        plainTextBuffer.writeln();
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.setPlainText(plainTextBuffer.toString());
      });

      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Excel parsing failed: $e";
          _isParsing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_excel != null) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isParsing) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE65A4B)));
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    if (_excel == null || _excel!.tables.isEmpty) {
      return const Center(child: Text("Empty Workbook"));
    }

    final sheetNames = _excel!.tables.keys.toList();
    final isDarkMode = widget.controller.isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0);
    final cardColor = isDarkMode ? const Color(0xFF3D3D3F) : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Sheet Selection Tabs
          Container(
            color: isDarkMode ? const Color(0xFF2D2D2F) : Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFE65A4B),
              labelColor: const Color(0xFFE65A4B),
              unselectedLabelColor: textColor.withOpacity(0.6),
              tabs: sheetNames.map((name) => Tab(text: name)).toList(),
            ),
          ),
          // Sheet Grid Renderers
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: sheetNames.map((name) {
                return _buildSheetGrid(_excel!.tables[name]!, isDarkMode, cardColor, textColor);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetGrid(xl.Sheet sheet, bool isDarkMode, Color cardColor, Color textColor) {
    if (sheet.rows.isEmpty) {
      return const Center(child: Text("Empty Sheet"));
    }

    return InteractiveViewer(
      constrained: false,
      maxScale: 2.0,
      minScale: 0.5,
      child: Container(
        color: cardColor,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: isDarkMode ? Colors.white12 : Colors.black12,
            width: 0.5,
          ),
          children: sheet.rows.map((row) {
            return TableRow(
              children: row.map((cell) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
                  child: Center(
                    child: Text(
                      cell?.value?.toString() ?? "",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}
