import 'dart:io';
import 'dart:math';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart';

class TextExtractionService {
  Future<String> extractText(String filePath) async {
    try {
      final ext = filePath.split('.').last.toLowerCase();
      debugPrint('TextExtraction: Extracting text from $ext file: $filePath');
      
      // Word document formats (.docx / .doc)
      if (ext == 'docx' || ext == 'doc') {
        return await _extractDocxText(filePath, ext);
      }

      // Presentation formats (.pptx / .ppt)
      if (ext == 'pptx' || ext == 'ppt') {
        return await _extractPptxText(filePath, ext);
      }

      // Text-based formats (direct read)
      if (_isTextBasedFormat(ext)) {
        return await _extractTextBased(filePath, ext);
      }
      
      // PDF (using Syncfusion)
      if (ext == 'pdf') {
        return await _extractPdfText(filePath);
      }
      
      // Spreadsheet formats (using Excel package)
      if (_isSpreadsheetFormat(ext)) {
        return await _extractSpreadsheetText(filePath, ext);
      }
      
      // RTF (Rich Text Format)
      if (ext == 'rtf') {
        return await _extractRtfText(filePath);
      }
      
      // eBook formats (basic text extraction)
      if (_isEbookFormat(ext)) {
        return await _extractEbookText(filePath, ext);
      }
      
      debugPrint('TextExtraction: Unsupported format for text extraction: $ext');
      return '';
    } catch (e) {
      debugPrint('TextExtraction Error: $e');
      return '';
    }
  }

  bool _isTextBasedFormat(String ext) {
    const textFormats = {
      'txt', 'md', 'xml', 'json', 'yaml', 'yml', 
      'tex', 'log', 'ini', 'cfg', 'csv', 'tsv'
    };
    return textFormats.contains(ext);
  }

  bool _isSpreadsheetFormat(String ext) {
    const spreadsheetFormats = {'xls', 'xlsx', 'ods', 'csv', 'tsv'};
    return spreadsheetFormats.contains(ext);
  }

  bool _isEbookFormat(String ext) {
    const ebookFormats = {'epub', 'mobi', 'azw', 'azw3', 'fb2'};
    return ebookFormats.contains(ext);
  }

  Future<String> _extractTextBased(String filePath, String ext) async {
    try {
      String content = await File(filePath).readAsString();
      
      // Handle CSV/TSV specifically for better formatting
      if (ext == 'csv' || ext == 'tsv') {
        return _formatCsvContent(content, ext == 'tsv');
      }
      
      return content;
    } catch (e) {
      debugPrint('TextExtraction Error reading text file: $e');
      return '';
    }
  }

  String _formatCsvContent(String content, bool isTsv) {
    final lines = content.split('\n');
    final buffer = StringBuffer();
    final separator = isTsv ? '\t' : ',';
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final cells = line.split(separator);
      buffer.writeln('Row ${i + 1}:');
      for (int j = 0; j < cells.length; j++) {
        buffer.writeln('  Column ${j + 1}: ${cells[j].trim()}');
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  // ---------------------------------------------------------------------------
  // .DOCX / .DOC — extract plain text from the embedded XML
  // ---------------------------------------------------------------------------
  //
  // A .docx file is a ZIP archive. The human-readable text lives inside
  // "word/document.xml".  We:
  //   1. Decode the ZIP bytes with the `archive` package (already in pubspec).
  //   2. Find the word/document.xml entry.
  //   3. Strip all XML tags with a regex and normalise whitespace.
  //
  // For legacy binary .doc files we fall back to a best-effort printable-ASCII
  // extraction (full OLE2 parsing would require an external native library).
  Future<String> _extractDocxText(String filePath, String ext) async {
    try {
      if (ext == 'docx') {
        final bytes = await File(filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Locate word/document.xml — case-insensitive search for robustness.
        final xmlEntry = archive.files.firstWhere(
          (f) => f.name.toLowerCase() == 'word/document.xml',
          orElse: () => throw Exception(
              'word/document.xml not found inside .docx archive'),
        );

        final rawXml = String.fromCharCodes(xmlEntry.content as List<int>);

        // Insert whitespace before paragraph/break/tab elements so that words
        // from adjacent tags don't concatenate.
        final spaced = rawXml
            .replaceAll(RegExp(r'<w:p[ />]'), '\n')
            .replaceAll(RegExp(r'<w:br[ />]'), '\n')
            .replaceAll(RegExp(r'<w:tab[ />]'), '\t');

        // Strip all remaining XML tags.
        final plain = spaced
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll(RegExp(r'&amp;'), '&')
            .replaceAll(RegExp(r'&lt;'), '<')
            .replaceAll(RegExp(r'&gt;'), '>')
            .replaceAll(RegExp(r'&apos;'), "'")
            .replaceAll(RegExp(r'&quot;'), '"')
            .replaceAll(RegExp(r'[ \t]+'), ' ')     // collapse inline spaces
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')  // max 2 blank lines
            .trim();

        debugPrint(
            'TextExtraction: .docx text extracted (${plain.length} chars)');
        return plain;
      } else {
        // Legacy binary .doc — best-effort: keep only printable ASCII / newlines.
        final bytes = await File(filePath).readAsBytes();
        final text = String.fromCharCodes(
          bytes.where(
              (b) => b == 0x0A || b == 0x0D || (b >= 0x20 && b < 0x7F)),
        )
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();
        debugPrint(
            'TextExtraction: .doc text extracted (best-effort, ${text.length} chars)');
        return text;
      }
    } catch (e) {
      debugPrint('TextExtraction Error extracting Word document: $e');
      return '';
    }
  }

  Future<String> _extractPptxText(String filePath, String ext) async {
    try {
      if (ext == 'pptx') {
        final bytes = await File(filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final buffer = StringBuffer();
        final slideFiles = archive.files
            .where((f) => RegExp(r'ppt/slides/slide\d+\.xml', caseSensitive: false).hasMatch(f.name))
            .toList();
        slideFiles.sort((a, b) => a.name.compareTo(b.name));

        int slideNum = 1;
        for (final file in slideFiles) {
          final rawXml = String.fromCharCodes(file.content as List<int>);
          final matches = RegExp(r'<a:t[^>]*>(.*?)</a:t>', dotAll: true).allMatches(rawXml);
          final texts = matches.map((m) => m.group(1) ?? '').where((t) => t.trim().isNotEmpty).toList();
          if (texts.isNotEmpty) {
            buffer.writeln('=== Slide $slideNum ===');
            buffer.writeln(texts.join(' '));
            buffer.writeln();
          }
          slideNum++;
        }
        final plain = buffer.toString().trim();
        debugPrint('TextExtraction: .pptx text extracted (${plain.length} chars)');
        return plain;
      } else {
        final bytes = await File(filePath).readAsBytes();
        final text = String.fromCharCodes(
          bytes.where((b) => b == 0x0A || b == 0x0D || (b >= 0x20 && b < 0x7F)),
        ).replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
        return text;
      }
    } catch (e) {
      debugPrint('TextExtraction Error extracting PowerPoint presentation: $e');
      return '';
    }
  }

  Future<String> _extractPdfText(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      debugPrint('TextExtraction: PDF text extracted successfully');
      return text;
    } catch (e) {
      debugPrint('TextExtraction Error extracting PDF: $e');
      return '';
    }
  }

  Future<String> _extractSpreadsheetText(String filePath, String ext) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      final buffer = StringBuffer();
      
      for (final table in excel.tables.keys) {
        buffer.writeln('=== Sheet: $table ===');
        final sheet = excel.tables[table];
        
        if (sheet != null) {
          for (int row = 0; row < sheet.rows.length; row++) {
            final rowData = sheet.rows[row];
            final cells = rowData.map((cell) {
              if (cell?.value != null) {
                return cell?.value?.toString() ?? '';
              }
              return '';
            }).where((cell) => cell.isNotEmpty).join(' | ');
            
            if (cells.isNotEmpty) {
              buffer.writeln('Row ${row + 1}: $cells');
            }
          }
        }
        buffer.writeln();
      }
      
      debugPrint('TextExtraction: Spreadsheet text extracted successfully');
      return buffer.toString();
    } catch (e) {
      debugPrint('TextExtraction Error extracting spreadsheet: $e');
      return '';
    }
  }

  Future<String> _extractRtfText(String filePath) async {
    try {
      // RTF files contain formatting codes, we'll do basic text extraction
      String content = await File(filePath).readAsString();
      
      // Remove RTF control words and formatting
      String text = content
          .replaceAll(RegExp(r'\\[a-z]+\d?'), '') // Remove control words
          .replaceAll(RegExp(r'\\[^a-z]'), '') // Remove other backslash commands
          .replaceAll(RegExp(r'\{[^}]*\}'), '') // Remove groups
          .replaceAll(RegExp(r'[{}]', multiLine: true), '') // Remove braces
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();
      
      debugPrint('TextExtraction: RTF text extracted (basic)');
      return text;
    } catch (e) {
      debugPrint('TextExtraction Error extracting RTF: $e');
      return '';
    }
  }

  Future<String> _extractEbookText(String filePath, String ext) async {
    try {
      // For eBooks, we'll attempt basic text extraction
      // Note: Full eBook parsing would require specialized libraries
      String content = await File(filePath).readAsString();
      
      // For EPUB (which is HTML-based), try to extract text from HTML tags
      if (ext == 'epub') {
        content = content
            .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ') // Remove HTML tags
            .replaceAll(RegExp(r'&[a-z]+;', multiLine: true), ' ') // Remove HTML entities
            .replaceAll(RegExp(r'\s+', multiLine: true), ' ') // Normalize whitespace
            .trim();
      }
      
      // For other eBook formats, basic extraction
      debugPrint('TextExtraction: eBook text extracted (basic for $ext)');
      return content;
    } catch (e) {
      debugPrint('TextExtraction Error extracting eBook: $e');
      return '';
    }
  }

  List<String> chunkByPages(String fullText, {int charsPerPage = 1800}) {
    if (fullText.isEmpty) return [];
    final chunks = <String>[];
    int start = 0;
    while (start < fullText.length) {
      final end = min(start + charsPerPage, fullText.length);
      int breakAt = end;
      if (end < fullText.length) {
        final nlIndex = fullText.lastIndexOf('\n', end);
        if (nlIndex > start) breakAt = nlIndex + 1;
      }
      chunks.add(fullText.substring(start, breakAt).trim());
      start = breakAt;
    }
    return chunks;
  }

  List<String> chunkByParagraphs(String fullText, {int maxChunkChars = 3000}) {
    final paragraphs = fullText.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final para in paragraphs) {
      if (buffer.length + para.length > maxChunkChars && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      buffer.write('$para\n\n');
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks;
  }

  String chunkForPage(List<String> chunks, int pageIndex) {
    if (chunks.isEmpty) return '';
    final idx = pageIndex.clamp(0, chunks.length - 1);
    return chunks[idx];
  }

  Map<int, String> buildPageIndex(List<String> chunks) {
    return {for (int i = 0; i < chunks.length; i++) i: chunks[i]};
  }
}