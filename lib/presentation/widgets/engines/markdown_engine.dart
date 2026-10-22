import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'base_engine.dart';

class MarkdownEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const MarkdownEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<MarkdownEngine> createState() => _MarkdownEngineState();
}

class _MarkdownEngineState extends State<MarkdownEngine> {
  bool _isLoading = true;
  String? _error;
  List<MdBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    _parseMarkdown();
  }

  @override
  void didUpdateWidget(MarkdownEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseMarkdown();
    }
  }

  Future<void> _parseMarkdown() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final content = await file.readAsString(encoding: utf8);

      final lines = content.split(RegExp(r'\r\n|\r|\n'));
      final List<MdBlock> parsed = [];

      bool inCodeBlock = false;
      final codeBuffer = StringBuffer();
      String codeLang = '';

      for (final line in lines) {
        if (line.trim().startsWith('```')) {
          if (inCodeBlock) {
            parsed.add(MdCodeBlock(code: codeBuffer.toString().trimRight(), language: codeLang));
            codeBuffer.clear();
            inCodeBlock = false;
          } else {
            inCodeBlock = true;
            codeLang = line.trim().replaceAll('```', '');
          }
          continue;
        }

        if (inCodeBlock) {
          codeBuffer.writeln(line);
          continue;
        }

        final trimmed = line.trim();

        if (trimmed.startsWith('# ')) {
          parsed.add(MdHeader(text: trimmed.substring(2), level: 1));
        } else if (trimmed.startsWith('## ')) {
          parsed.add(MdHeader(text: trimmed.substring(3), level: 2));
        } else if (trimmed.startsWith('### ')) {
          parsed.add(MdHeader(text: trimmed.substring(4), level: 3));
        } else if (trimmed.startsWith('#### ')) {
          parsed.add(MdHeader(text: trimmed.substring(5), level: 4));
        } else if (trimmed.startsWith('> ')) {
          parsed.add(MdQuote(text: trimmed.substring(2)));
        } else if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('* [ ] ')) {
          parsed.add(MdChecklist(text: trimmed.substring(6), checked: false));
        } else if (trimmed.startsWith('- [x] ') || trimmed.startsWith('* [x] ')) {
          parsed.add(MdChecklist(text: trimmed.substring(6), checked: true));
        } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          parsed.add(MdBullet(text: trimmed.substring(2)));
        } else if (trimmed.isNotEmpty) {
          parsed.add(MdParagraph(text: line));
        } else {
          parsed.add(MdSpacer());
        }
      }

      if (inCodeBlock && codeBuffer.isNotEmpty) {
        parsed.add(MdCodeBlock(code: codeBuffer.toString(), language: codeLang));
      }

      setState(() {
        _blocks = parsed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to parse Markdown document: $e';
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

    if (_error != null) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error!,
        isDarkMode: widget.isDarkMode,
        onRetry: _parseMarkdown,
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
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _blocks.length,
            itemBuilder: (context, idx) {
              final block = _blocks[idx];

              if (block is MdHeader) {
                final double fontSize = block.level == 1 ? 24 : (block.level == 2 ? 20 : 17);
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    block.text,
                    style: TextStyle(
                      color: widget.isDarkMode && block.level == 1 ? EngineColors.coralAccent : textColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              } else if (block is MdParagraph) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    block.text,
                    style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
                  ),
                );
              } else if (block is MdCodeBlock) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EngineColors.coralAccent.withValues(alpha: 0.3)),
                  ),
                  child: SelectableText(
                    block.code,
                    style: TextStyle(
                      color: widget.isDarkMode ? const Color(0xFFD4D4D4) : const Color(0xFF333333),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                );
              } else if (block is MdQuote) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EngineColors.coralAccent.withValues(alpha: 0.1),
                    border: const Border(
                      left: BorderSide(color: EngineColors.coralAccent, width: 4),
                    ),
                  ),
                  child: Text(
                    block.text,
                    style: TextStyle(color: textColor, fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                );
              } else if (block is MdBullet) {
                return Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: EngineColors.coralAccent, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(block.text, style: TextStyle(color: textColor, fontSize: 14))),
                    ],
                  ),
                );
              } else if (block is MdChecklist) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        block.checked ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 18,
                        color: block.checked ? EngineColors.coralAccent : textColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          block.text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            decoration: block.checked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox(height: 8);
            },
          ),
        ),
      ),
    );
  }
}

abstract class MdBlock {}

class MdHeader extends MdBlock {
  final String text;
  final int level;
  MdHeader({required this.text, required this.level});
}

class MdParagraph extends MdBlock {
  final String text;
  MdParagraph({required this.text});
}

class MdCodeBlock extends MdBlock {
  final String code;
  final String language;
  MdCodeBlock({required this.code, required this.language});
}

class MdQuote extends MdBlock {
  final String text;
  MdQuote({required this.text});
}

class MdBullet extends MdBlock {
  final String text;
  MdBullet({required this.text});
}

class MdChecklist extends MdBlock {
  final String text;
  final bool checked;
  MdChecklist({required this.text, required this.checked});
}

class MdSpacer extends MdBlock {}
