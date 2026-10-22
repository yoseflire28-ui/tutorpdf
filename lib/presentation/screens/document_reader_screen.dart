import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:excel/excel.dart' as excel;
import 'package:csv/csv.dart';
import 'package:docx_to_text/docx_to_text.dart';
import '../../screens/reader_screen.dart';
import '../../core/app_theme.dart';
import '../../data/providers/settings_provider.dart';

/// Central document router that dispatches to appropriate viewer based on file type
class DocumentReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const DocumentReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  double _fontSize = 16.0;
  bool _isDarkMode = false;
  String? _fileExtension;

  @override
  void initState() {
    super.initState();
    _fileExtension = widget.fileName.split('.').last.toLowerCase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      setState(() {
        _isDarkMode = settings.isDarkMode;
      });
    });
  }

  void _toggleTheme() {
    final settings = context.read<SettingsProvider>();
    settings.updateSettingParam('isDarkMode', !settings.isDarkMode);
    setState(() {
      _isDarkMode = settings.isDarkMode;
    });
  }

  void _increaseFontSize() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(12.0, 32.0);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(12.0, 32.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode ? AppTheme.darkBackground : AppTheme.creamBackground;
    final appBarColor = AppTheme.charcoalCard;
    final textColor = AppTheme.offWhiteText;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.offWhiteText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.fileName,
                    style: const TextStyle(
                      color: AppTheme.offWhiteText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_fileExtension != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.coralAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _fileExtension!.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.offWhiteText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: AppTheme.offWhiteText),
            onPressed: _toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: AppTheme.offWhiteText),
            onPressed: _decreaseFontSize,
            tooltip: 'Decrease Font Size',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.offWhiteText),
            onPressed: _increaseFontSize,
            tooltip: 'Increase Font Size',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildDocumentViewer(),
    );
  }

  Widget _buildDocumentViewer() {
    switch (_fileExtension) {
      case 'pdf':
        return PdfViewerWidget(filePath: widget.filePath, isDarkMode: _isDarkMode);
      case 'docx':
      case 'pptx':
      case 'xlsx':
      case 'epub':
      case 'html':
      case 'rtf':
      case 'csv':
      case 'txt':
      case 'log':
        return ReaderScreen(filePath: widget.filePath, title: widget.fileName);
      default:
        return _buildUnsupportedView('Unsupported file type: $_fileExtension');
    }
  }

  Widget _buildUnsupportedView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.coralAccent),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.offWhiteText,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// PDF Viewer using Syncfusion
class PdfViewerWidget extends StatelessWidget {
  final String filePath;
  final bool isDarkMode;

  const PdfViewerWidget({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    Widget viewer = SfPdfViewer.file(
      File(filePath),
      canShowScrollHead: true,
      canShowScrollStatus: true,
      canShowPaginationDialog: true,
      pageSpacing: 8,
      enableTextSelection: true,
    );

    if (isDarkMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: viewer,
      );
    }

    return viewer;
  }
}

/// DOCX and TXT Reader View
class DocxReaderView extends StatefulWidget {
  final String filePath;
  final double fontSize;
  final bool isDarkMode;

  const DocxReaderView({
    super.key,
    required this.filePath,
    required this.fontSize,
    required this.isDarkMode,
  });

  @override
  State<DocxReaderView> createState() => _DocxReaderViewState();
}

class _DocxReaderViewState extends State<DocxReaderView> {
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final file = File(widget.filePath);
      final extension = widget.filePath.split('.').last.toLowerCase();
      
      if (extension == 'docx') {
        final bytes = await file.readAsBytes();
        _content = await docxToText(bytes);
      } else {
        _content = await file.readAsString();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _content = 'Error loading document: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paperColor = widget.isDarkMode ? AppTheme.charcoalCard : const Color(0xFFFAFAFA);
    final textColor = widget.isDarkMode ? AppTheme.offWhiteText : const Color(0xFF2C2C2C);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.coralAccent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: paperColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SelectableText(
          _content,
          style: TextStyle(
            color: textColor,
            fontSize: widget.fontSize,
            height: 1.6,
            fontFamily: 'Georgia',
          ),
        ),
      ),
    );
  }
}

/// PowerPoint Slide View (simplified - renders as text content)
class PptxSlideView extends StatefulWidget {
  final String filePath;
  final double fontSize;
  final bool isDarkMode;

  const PptxSlideView({
    super.key,
    required this.filePath,
    required this.fontSize,
    required this.isDarkMode,
  });

  @override
  State<PptxSlideView> createState() => _PptxSlideViewState();
}

class _PptxSlideViewState extends State<PptxSlideView> {
  List<String> _slides = [];
  int _currentSlide = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPresentation();
  }

  Future<void> _loadPresentation() async {
    try {
      // Note: Full PPTX parsing requires additional libraries
      // This is a simplified implementation that extracts text
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      
      // For now, we'll create placeholder slides
      // In production, use a proper PPTX parser library
      setState(() {
        _slides = [
          'Slide 1: Presentation Title\n\nContent placeholder',
          'Slide 2: Overview\n\nContent placeholder',
          'Slide 3: Details\n\nContent placeholder',
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _slides = ['Error loading presentation: $e'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slideColor = widget.isDarkMode ? AppTheme.charcoalCard : const Color(0xFFFAFAFA);
    final textColor = widget.isDarkMode ? AppTheme.offWhiteText : const Color(0xFF2C2C2C);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.coralAccent),
      );
    }

    if (_slides.isEmpty) {
      return Center(
        child: Text(
          'No slides found',
          style: TextStyle(color: textColor, fontSize: widget.fontSize),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentSlide = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: slideColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: SelectableText(
                    _slides[index],
                    style: TextStyle(
                      color: textColor,
                      fontSize: widget.fontSize,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.charcoalCard,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Slide ${_currentSlide + 1} of ${_slides.length}',
                style: const TextStyle(
                  color: AppTheme.offWhiteText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Excel and CSV Data Grid View
class ExcelDataGrid extends StatefulWidget {
  final String filePath;
  final String fileExtension;
  final bool isDarkMode;

  const ExcelDataGrid({
    super.key,
    required this.filePath,
    required this.fileExtension,
    required this.isDarkMode,
  });

  @override
  State<ExcelDataGrid> createState() => _ExcelDataGridState();
}

class _ExcelDataGridState extends State<ExcelDataGrid> {
  List<List<String>> _data = [];
  List<String> _headers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final file = File(widget.filePath);
      
      if (widget.fileExtension == 'csv') {
        final csvContent = await file.readAsString();
        final rows = const CsvToListConverter().convert(csvContent);
        
        if (rows.isNotEmpty) {
          _headers = rows.first.map((e) => e.toString()).toList();
          _data = rows.skip(1).map((row) => row.map((e) => e.toString()).toList()).toList();
        }
      } else if (widget.fileExtension == 'xlsx') {
        final bytes = await file.readAsBytes();
        final excelDoc = excel.Excel.decodeBytes(bytes);
        
        for (final table in excelDoc.tables.keys) {
          final sheet = excelDoc.tables[table]!;
          if (sheet.rows.isNotEmpty) {
            _headers = sheet.rows.first.map((e) => e?.value?.toString() ?? '').toList();
            _data = sheet.rows.skip(1).map((row) {
              return row.map((e) => e?.value?.toString() ?? '').toList();
            }).toList();
            break;
          }
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _data = [['Error: $e']];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gridColor = widget.isDarkMode ? AppTheme.charcoalCard : Colors.white;
    final headerColor = AppTheme.coralAccent;
    final textColor = widget.isDarkMode ? AppTheme.offWhiteText : Colors.black87;
    final borderColor = widget.isDarkMode ? AppTheme.offWhiteText.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.3);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.coralAccent),
      );
    }

    if (_data.isEmpty) {
      return Center(
        child: Text(
          'No data found',
          style: TextStyle(color: textColor),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          border: TableBorder(
            horizontalInside: BorderSide(color: borderColor),
            verticalInside: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
          ),
          headingRowColor: MaterialStateProperty.all(headerColor),
          dataRowColor: MaterialStateProperty.all(gridColor),
          columns: _headers.map((header) {
            return DataColumn(
              label: Text(
                header,
                style: const TextStyle(
                  color: AppTheme.offWhiteText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
          rows: _data.map((row) {
            return DataRow(
              cells: row.map((cell) {
                return DataCell(
                  Text(
                    cell,
                    style: TextStyle(color: textColor),
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

