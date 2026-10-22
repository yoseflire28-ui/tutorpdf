import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'base_engine.dart';

class OdtEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const OdtEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<OdtEngine> createState() => _OdtEngineState();
}

class _OdtEngineState extends State<OdtEngine> {
  bool _isLoading = true;
  String? _error;
  List<OdtNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    _parseOdt();
  }

  @override
  void didUpdateWidget(OdtEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseOdt();
    }
  }

  Future<void> _parseOdt() async {
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
          _error = 'content.xml missing from ODT package.';
          _isLoading = false;
        });
        return;
      }

      final contentStr = utf8.decode(contentFile.content as List<int>, allowMalformed: true);
      final doc = xml.XmlDocument.parse(contentStr);
      final body = doc.findAllElements('office:text').firstOrNull;

      final List<OdtNode> parsed = [];

      if (body != null) {
        for (final child in body.children) {
          if (child is xml.XmlElement) {
            final name = child.name.local;
            if (name == 'h') {
              parsed.add(OdtParagraph(text: child.innerText, isHeading: true));
            } else if (name == 'p') {
              if (child.innerText.trim().isNotEmpty) {
                parsed.add(OdtParagraph(text: child.innerText, isHeading: false));
              }
            } else if (name == 'table') {
              final rows = <List<String>>[];
              for (final tr in child.findAllElements('table:table-row')) {
                final row = <String>[];
                for (final tc in tr.findAllElements('table:table-cell')) {
                  row.add(tc.innerText.trim());
                }
                if (row.isNotEmpty) rows.add(row);
              }
              if (rows.isNotEmpty) parsed.add(OdtTable(rows: rows));
            }
          }
        }
      }

      if (parsed.isNotEmpty) {
        setState(() {
          _nodes = parsed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No text content found in OpenDocument document.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to parse ODT OpenDocument text: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasBg = widget.isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas;
    final cardBg = widget.isDarkMode ? EngineColors.darkCard : EngineColors.lightCard;
    final textColor = widget.isDarkMode ? EngineColors.darkText : EngineColors.lightText;

    if (_isLoading) {
      return Container(
        color: canvasBg,
        child: const Center(
          child: CircularProgressIndicator(color: EngineColors.coralAccent),
        ),
      );
    }

    if (_error != null || _nodes.isEmpty) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error ?? 'Unable to display ODT file.',
        isDarkMode: widget.isDarkMode,
        onRetry: _parseOdt,
      );
    }

    return Container(
      color: canvasBg,
      width: double.infinity,
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _nodes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final node = _nodes[idx];
              if (node is OdtParagraph) {
                return Text(
                  node.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: node.isHeading ? 20 : 15,
                    fontWeight: node.isHeading ? FontWeight.bold : FontWeight.normal,
                    height: 1.5,
                  ),
                );
              } else if (node is OdtTable) {
                return Table(
                  border: TableBorder.all(color: textColor.withValues(alpha: 0.3)),
                  children: node.rows.map((r) {
                    return TableRow(
                      children: r.map((cell) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(cell, style: TextStyle(color: textColor, fontSize: 13)),
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

abstract class OdtNode {}

class OdtParagraph extends OdtNode {
  final String text;
  final bool isHeading;
  OdtParagraph({required this.text, required this.isHeading});
}

class OdtTable extends OdtNode {
  final List<List<String>> rows;
  OdtTable({required this.rows});
}
